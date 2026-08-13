//+------------------------------------------------------------------+
//|                                           LBR_3_10_Oscillator.mq5|
//|                        LBR 3-10 Oscillator by Linda Raschke      |
//|              Adapted from Pine Script by bonfireAlgorithm          |
//+------------------------------------------------------------------+
#property copyright   "Free for all"
#property link        "https://www.mql5.com"
#property description "LBR 3-10 Oscillator (Linda Bradford Raschke)\n"
                      "Fast=3, Slow=10, Signal=16. SMA/EMA switchable."
//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   5
//--- histogram (MACD line plotted as histogram, matching Pine Script)
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label1  "Histogram"
//--- MACD line
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_label2  "Hist Line"
//--- signal line
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLightCoral
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_label3  "Signal"
//--- upper std band
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGray
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
#property indicator_label4  "Upper Band"
//--- lower std band
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGray
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1
#property indicator_label5  "Lower Band"
//--- input parameters
input int                InpFastLength=3;             // Fast Length
input int                InpSlowLength=10;            // Slow Length
input ENUM_APPLIED_PRICE InpSource=PRICE_CLOSE;       // Source
input double             InpStDev=1.5;                // St. dev.
input int                InpStDevLength=100;          // St. dev. length
input int                InpSignalLength=16;          // Signal Smoothing
input bool               InpSmaSource=true;           // Simple MA(Oscillator)
input bool               InpSmaSignal=true;           // Simple MA(Signal Line)
input bool               InpShowStdBands=false;       // Show std. bands
input bool               InpVolatilityNormalized=false;// Volatility normalized
//--- indicator buffers
double ExtMacdBuffer[];        // MACD line (fast MA - slow MA)
double ExtHistBuffer[];        // Histogram = MACD line (as in Pine Script)
double ExtSignalBuffer[];      // Signal line
double ExtUpperBandBuffer[];   // Upper std band
double ExtLowerBandBuffer[];   // Lower std band
double ExtFastMaBuffer[];      // Fast MA calculation buffer
double ExtSlowMaBuffer[];      // Slow MA calculation buffer
//--- handles
int    ExtFastMaHandle;
int    ExtSlowMaHandle;
int    ExtAtrHandle;
//+------------------------------------------------------------------+
//| Safe value check                                                 |
//+------------------------------------------------------------------+
bool IsValidDouble(const double value)
  {
   return(MathIsValidNumber(value) && value!=0.0 && value!=DBL_MAX && value!=-DBL_MAX);
  }
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- validate input parameters
   if(InpFastLength<1 || InpSlowLength<1 || InpSignalLength<1)
     {
      Print("Error: Periods must be >= 1");
      return;
     }
   if(InpFastLength>=InpSlowLength)
     {
      Print("Error: Fast Length must be less than Slow Length");
      return;
     }
   if(InpStDevLength<2)
     {
      Print("Error: St. dev. length must be >= 2");
      return;
     }
   if(InpStDev<0.0)
     {
      Print("Error: St. dev. must be >= 0");
      return;
     }
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtHistBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtMacdBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtSignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtUpperBandBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,ExtLowerBandBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,ExtFastMaBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,ExtSlowMaBuffer,INDICATOR_CALCULATIONS);
//--- initialize buffers
   ArrayInitialize(ExtMacdBuffer,0.0);
   ArrayInitialize(ExtHistBuffer,0.0);
   ArrayInitialize(ExtSignalBuffer,0.0);
   ArrayInitialize(ExtUpperBandBuffer,EMPTY_VALUE);
   ArrayInitialize(ExtLowerBandBuffer,EMPTY_VALUE);
   ArrayInitialize(ExtFastMaBuffer,0.0);
   ArrayInitialize(ExtSlowMaBuffer,0.0);
//--- sets first bar from what index will be drawn
   int max_period=MathMax(InpSlowLength,InpSignalLength);
   max_period=MathMax(max_period,InpStDevLength);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,max_period-1);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpSlowLength-1);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,InpSignalLength-1);
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,max_period-1);
   PlotIndexSetInteger(4,PLOT_DRAW_BEGIN,max_period-1);
//--- zero line
   IndicatorSetInteger(INDICATOR_LEVELS,1);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrDarkGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELWIDTH,0,1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,0.0);
//--- name for indicator subwindow label
   string ma_src=InpSmaSource ? "SMA" : "EMA";
   string ma_sig=InpSmaSignal ? "SMA" : "EMA";
   string short_name=StringFormat("LBR 3-10(%s%d,%s%d,%s%d)",ma_src,InpFastLength,ma_src,InpSlowLength,ma_sig,InpSignalLength);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
//--- get MA handles
   ENUM_MA_METHOD fast_method=InpSmaSource ? MODE_SMA : MODE_EMA;
   ENUM_MA_METHOD slow_method=InpSmaSource ? MODE_SMA : MODE_EMA;
   ExtFastMaHandle=iMA(NULL,0,InpFastLength,0,fast_method,InpSource);
   ExtSlowMaHandle=iMA(NULL,0,InpSlowLength,0,slow_method,InpSource);
//--- get ATR handle for volatility normalization
   ExtAtrHandle=iATR(NULL,0,InpSlowLength);
//--- check handles
   if(ExtFastMaHandle==INVALID_HANDLE || ExtSlowMaHandle==INVALID_HANDLE)
     {
      Print("Failed to create MA handles. Error ",GetLastError());
      return;
     }
   if(InpVolatilityNormalized && ExtAtrHandle==INVALID_HANDLE)
     {
      Print("Failed to create ATR handle. Error ",GetLastError());
      return;
     }
  }
//+------------------------------------------------------------------+
//| LBR 3-10 Oscillator                                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int max_period=MathMax(InpSlowLength,InpSignalLength);
   max_period=MathMax(max_period,InpStDevLength);
   if(rates_total<max_period)
      return(0);
//--- not all data may be calculated
   int calculated=BarsCalculated(ExtFastMaHandle);
   if(calculated<rates_total)
     {
      Print("Not all data of Fast MA is calculated (",calculated," bars). Error ",GetLastError());
      return(0);
     }
   calculated=BarsCalculated(ExtSlowMaHandle);
   if(calculated<rates_total)
     {
      Print("Not all data of Slow MA is calculated (",calculated," bars). Error ",GetLastError());
      return(0);
     }
   if(InpVolatilityNormalized)
     {
      calculated=BarsCalculated(ExtAtrHandle);
      if(calculated<rates_total)
        {
         Print("Not all data of ATR is calculated (",calculated," bars). Error ",GetLastError());
         return(0);
        }
     }
//--- we can copy not all data
   int to_copy;
   if(prev_calculated>rates_total || prev_calculated<0)
      to_copy=rates_total;
   else
     {
      to_copy=rates_total-prev_calculated;
      if(prev_calculated>0)
         to_copy++;
     }
//--- get Fast MA buffer
   if(IsStopped())
      return(0);
   if(CopyBuffer(ExtFastMaHandle,0,0,to_copy,ExtFastMaBuffer)<=0)
     {
      Print("Getting fast MA is failed! Error ",GetLastError());
      return(0);
     }
//--- get Slow MA buffer
   if(IsStopped())
      return(0);
   if(CopyBuffer(ExtSlowMaHandle,0,0,to_copy,ExtSlowMaBuffer)<=0)
     {
      Print("Getting slow MA is failed! Error ",GetLastError());
      return(0);
     }
//--- get ATR buffer if needed
   double atr_buffer[];
   if(InpVolatilityNormalized)
     {
      ArraySetAsSeries(atr_buffer,false);
      ArrayInitialize(atr_buffer,0.0);
      if(CopyBuffer(ExtAtrHandle,0,0,to_copy,atr_buffer)<=0)
        {
         Print("Getting ATR is failed! Error ",GetLastError());
         return(0);
        }
     }
//--- calculate MACD
   int start;
   if(prev_calculated==0)
      start=0;
   else
      start=prev_calculated-1;

   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      double fast_val=ExtFastMaBuffer[i];
      double slow_val=ExtSlowMaBuffer[i];

      if(!MathIsValidNumber(fast_val) || !MathIsValidNumber(slow_val))
        {
         ExtMacdBuffer[i]=0.0;
         continue;
        }

      double diff=fast_val-slow_val;

      if(InpVolatilityNormalized)
        {
         double atr=atr_buffer[i];
         if(IsValidDouble(atr))
            ExtMacdBuffer[i]=(diff/atr)*100.0;
         else
            ExtMacdBuffer[i]=0.0;
        }
      else
         ExtMacdBuffer[i]=diff;
     }
//--- calculate Signal line manually (SMA or EMA of MACD)
   if(InpSmaSignal)
     {
      // SMA of MACD
      for(int i=start; i<rates_total && !IsStopped(); i++)
        {
         if(i<InpSignalLength-1)
           {
            ExtSignalBuffer[i]=0.0;
            continue;
           }
         double sum=0.0;
         int count=0;
         for(int j=0; j<InpSignalLength; j++)
           {
            double val=ExtMacdBuffer[i-j];
            if(MathIsValidNumber(val))
              {
               sum+=val;
               count++;
              }
           }
         if(count>0)
            ExtSignalBuffer[i]=sum/count;
         else
            ExtSignalBuffer[i]=0.0;
        }
     }
   else
     {
      // EMA of MACD
      double alpha=2.0/(InpSignalLength+1.0);
      for(int i=start; i<rates_total && !IsStopped(); i++)
        {
         double val=ExtMacdBuffer[i];
         if(!MathIsValidNumber(val))
           {
            ExtSignalBuffer[i]=0.0;
            continue;
           }
         if(i==0 || !MathIsValidNumber(ExtSignalBuffer[i-1]))
            ExtSignalBuffer[i]=val;
         else
            ExtSignalBuffer[i]=val*alpha+ExtSignalBuffer[i-1]*(1.0-alpha);
        }
     }
//--- calculate Histogram (matches Pine Script: MACD line as histogram)
   for(int i=start; i<rates_total && !IsStopped(); i++)
      ExtHistBuffer[i]=ExtMacdBuffer[i];
//--- calculate std bands
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      if(!InpShowStdBands || i<InpStDevLength-1)
        {
         ExtUpperBandBuffer[i]=EMPTY_VALUE;
         ExtLowerBandBuffer[i]=EMPTY_VALUE;
         continue;
        }

      double mean=0.0;
      int valid_count=0;
      for(int j=0; j<InpStDevLength; j++)
        {
         double val=ExtMacdBuffer[i-j];
         if(MathIsValidNumber(val))
           {
            mean+=val;
            valid_count++;
           }
        }

      if(valid_count<2)
        {
         ExtUpperBandBuffer[i]=EMPTY_VALUE;
         ExtLowerBandBuffer[i]=EMPTY_VALUE;
         continue;
        }

      mean/=valid_count;
      double sum_sq=0.0;
      for(int j=0; j<InpStDevLength; j++)
        {
         double val=ExtMacdBuffer[i-j];
         if(MathIsValidNumber(val))
           {
            double d=val-mean;
            sum_sq+=d*d;
           }
        }

      double std=MathSqrt(sum_sq/(valid_count-1));
      if(MathIsValidNumber(std))
        {
         ExtUpperBandBuffer[i]=InpStDev*std;
         ExtLowerBandBuffer[i]=-InpStDev*std;
        }
      else
        {
         ExtUpperBandBuffer[i]=EMPTY_VALUE;
         ExtLowerBandBuffer[i]=EMPTY_VALUE;
        }
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
