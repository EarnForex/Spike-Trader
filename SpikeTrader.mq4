//+------------------------------------------------------------------+
//|                                                  SpikeTrader.mq4 |
//|                             Copyright © 2012-2022, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-expert-advisors/Spike-Trader/"
#property version   "1.01"
#property strict

#property description "Trades on spikes that are:"
#property description "1) Higher/lower than N preceding bars;"
#property description "2) Higher/lower than the previous bar by X percent;"
#property description "3) Close in bottom or upper third/half of the bar."

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
input int Magic = 173923183;

int LastBars = 0;
int Timer = 0;

void OnTick()
{
    if ((!IsTradeAllowed()) || (IsTradeContextBusy()) || (!IsConnected()) || ((!MarketInfo(Symbol(), MODE_TRADEALLOWED)) && (!IsTesting()))) return;

    //Wait for the new Bar in a chart.
    if (LastBars == Bars) return;
    else LastBars = Bars;

    if (Timer == 1) ClosePrev();
    if (Timer > 0) Timer--;

    CheckEntry();
}

//+------------------------------------------------------------------+
//| Check for entry conditions and trade if necessary.               |
//+------------------------------------------------------------------+
void CheckEntry()
{
    // Empty bar.
    if (High[1] - Low[1] == 0) return;
    
    if (CheckSellEntry())
    {
        // If found a BUY order, close it and open a SELL. Otherwise, only reset timer.
        if (ClosePrev(OP_SELL)) fSell();
        Timer = Hold;
    }
    else if (CheckBuyEntry())
    {
        // If found a SELL order, close it and open a BUY. Otherwise, only reset timer.
        if (ClosePrev(OP_BUY)) fBuy();
        Timer = Hold;
    }
}

bool CheckSellEntry()
{
    // If the bar isn't higher than at least one of the previous bars - return false.
    for (int i = 2; i < BarsNumber + 2; i++)
        if (High[1] <= High[i]) return false;

    // If not higher than the previous bar by required percentage difference - return false.
    if ((High[1] - High[2]) / High[2] < PercentageDifference) return false;
    
    // If closed above the lower third/half - return false.
    if ((Close[1] - Low[1]) / (High[1] - Low[1]) > ThirdOrHalf) return false;

    // Passed all tests.
    return true;
}

bool CheckBuyEntry()
{
    // If the bar isn't lower than at least one of the previous bars - return false.
    for (int i = 2; i < BarsNumber + 2; i++)
        if (Low[1] >= Low[i]) return false;

    // If not lower than the previous bar by required percentage difference - return false.
    if ((Low[2] - Low[1]) / Low[2] < PercentageDifference) return false;
    
    // If closed below the upper third/half - return false.
    if ((High[1] - Close[1]) / (High[1] - Low[1]) > ThirdOrHalf) return false;

    // Passed all tests.
    return true;
}

//+------------------------------------------------------------------+
//| Close previous position.                                         |
//| order_type - skip positions of this directions.                  |
//+------------------------------------------------------------------+
bool ClosePrev(int order_type = -1)
{
    int total = OrdersTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) == false) continue;
        if ((OrderSymbol() == Symbol()) && (OrderMagicNumber() == Magic))
        {
            if (OrderType() == OP_BUY)
            {
                if (order_type == OP_BUY) return false;
                RefreshRates();
                if (!OrderClose(OrderTicket(), OrderLots(), Bid, Slippage))
                {
                    int e = GetLastError();
                    Print("OrderClose Error: ", e);
                }
                return true;
            }
            else if (OrderType() == OP_SELL)
            {
                if (order_type == OP_SELL) return false;
                RefreshRates();
                if (!OrderClose(OrderTicket(), OrderLots(), Ask, Slippage))
                {
                    int e = GetLastError();
                    Print("OrderClose Error: ", e);
                }
                return true;
            }
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
int fSell()
{
    RefreshRates();
    int result = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, 0, 0, OrderCommentary, Magic);
    if (result == -1)
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
    else return result;
    return 0;
}

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
int fBuy()
{
    RefreshRates();
    int result = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, 0, 0, OrderCommentary, Magic);
    if (result == -1)
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
    else return result;
    return 0;
}
//+------------------------------------------------------------------+