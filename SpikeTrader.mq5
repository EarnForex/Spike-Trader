//+------------------------------------------------------------------+
//|                                                  SpikeTrader.mq5 |
//|                             Copyright © 2012-2022, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-expert-advisors/Spike-Trader/"
#property version   "1.01"

#property description "Trades on spikes that are:"
#property description "1) Higher/lower than N preceding bars;"
#property description "2) Higher/lower than the previous bar by X percent;"
#property description "3) Close in bottom or upper third/half of the bar."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

input group "Main"
input int Hold = 11; // Hold: Position holding time in bars.
input int BarsNumber = 3; // BarsNumber: N preceding bars to check.
input double PercentageDifference = 0.003; // PercentageDifference1: X percentage for bar comparison.
input double ThirdOrHalf = 0.5; // ThirdOrHalf: Top/bottom share of a bar to close in.
input group "Money management"
input double Lots = 0.1;
input group "Miscellaneous"
input int Slippage = 30;
input string OrderCommentary = "Spike Trader";

int LastBars = 0;
int Timer = 0;

CTrade *Trade;
CPositionInfo PositionInfo;

void OnInit()
{
    // Initialize the Trade class object.
    Trade = new CTrade;
    Trade.SetDeviationInPoints(Slippage);
}

void OnDeinit(const int reason)
{
    delete Trade;
}

void OnTick()
{
    //Wait for the new Bar in a chart.
    if (LastBars == Bars(_Symbol, _Period)) return;
    else LastBars = Bars(_Symbol, _Period);

    if (Timer == 1) Trade.PositionClose(_Symbol);
    if (Timer > 0) Timer--;

    CheckEntry();
}

//+------------------------------------------------------------------+
//| Check for entry conditions and trade if necessary.               |
//+------------------------------------------------------------------+
void CheckEntry()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, _Period, 1, BarsNumber + 1, rates);
    if (copied != BarsNumber + 1) Print("Error copying price data ", GetLastError());

    // Empty bar.
    if (rates[0].high - rates[0].low == 0) return;

    if (CheckSellEntry(rates))
    {
        if (PositionInfo.Select(_Symbol))
        {
            // If same direction - just reset the timer.
            if (PositionInfo.PositionType() == POSITION_TYPE_SELL)
            {
                Timer = Hold;
                return;
            }
            else Trade.PositionClose(_Symbol);
        }
        double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        Trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, Lots, Bid, 0, 0, OrderCommentary);
        Timer = Hold;
    }
    else if (CheckBuyEntry(rates))
    {
        if (PositionInfo.Select(_Symbol))
        {
            // If same direction - just reset the timer.
            if (PositionInfo.PositionType() == POSITION_TYPE_BUY)
            {
                Timer = Hold;
                return;
            }
            else Trade.PositionClose(_Symbol);
        }
        double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        Trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, Lots, Ask, 0, 0, OrderCommentary);
        Timer = Hold;
    }
}

bool CheckSellEntry(MqlRates &rates[])
{
    // If the bar isn't higher than at least one of the previous bars - return false.
    for (int i = 1; i < BarsNumber + 1; i++)
        if (rates[0].high <= rates[i].high) return false;

    // If not higher than the previous bar by required percentage difference - return false.
    if ((rates[0].high - rates[1].high) / rates[1].high < PercentageDifference) return false;
    
    // If closed above the lower third/half - return false.
    if ((rates[0].close - rates[0].low) / (rates[0].high - rates[0].low) > ThirdOrHalf) return false;

    return true;
}

bool CheckBuyEntry(MqlRates &rates[])
{
    // If the bar isn't lower than at least one of the previous bars - return false.
    for (int i = 1; i < BarsNumber + 1; i++)
        if (rates[0].low >= rates[i].low) return false;

    // If not lower than the previous bar by required percentage difference - return false.
    if ((rates[1].low - rates[0].low) / rates[1].low < PercentageDifference) return false;

    // If closed below the upper third/half - return false.
    if ((rates[0].high - rates[0].close) / (rates[0].high - rates[0].low) > ThirdOrHalf) return false;

    return true;
}
//+------------------------------------------------------------------+