{
----------------------------------------------------------------------------------------------------
    Filename:       RV3028-Demo.spin
    Description:    Demo of the RV3028 driver
        * Time/Date output
    Author:         Jesse Burt
    Started:        Sep 6, 2020
    Updated:        Aug 11, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine in the driver
'#define RV3028_I2C_BC
'#pragma exportdef(RV3028_I2C_BC)


CON

    _clkmode    = cfg._clkmode
    _xinfreq    = cfg._xinfreq


' Named constants that can be used in place of numerical month, or weekday
    #1, JAN, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC
    #1, SUN, MON, TUE, WED, THU, FRI, SAT


OBJ

    cfg:    "boardcfg.flip"
    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    rtc:    "time.rtc.rv3028" | SCL=28, SDA=29, I2C_FREQ=400_000


PUB main()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( rtc.start() )
        ser.strln(@"RV3028 driver started")
    else
        ser.strln(@"RV3028 driver failed to start - halting")
        repeat

' Uncomment the line below to set or change the date/time
'    set_date_time(11, 44, 00, AUG, 11, SUN, 24)
'   (this only needs to be done once as long as RTC remains powered afterwards)
'                hh, mm, ss, MMM, DD, WKDAY, YY

    demo()

#include "timedemo.common.spinh"                ' use code common to all RTC demos

DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

