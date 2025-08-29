{
----------------------------------------------------------------------------------------------------
    Filename:       RV3028-Demo.spin
    Description:    Demo of the RV3028 driver
        * Time/Date output
    Author:         Jesse Burt
    Started:        Sep 6, 2020
    Updated:        Aug 29, 2025
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine in the driver
'#define RV3028_I2C_BC
'#pragma exportdef(RV3028_I2C_BC)


CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


' Named constants that can be used in place of numerical month, or weekday
    #1, JAN, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC
    #1, SUN, MON, TUE, WED, THU, FRI, SAT


OBJ

    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    rtc:    "time.rtc.rv3028" | SCL=28, SDA=29, I2C_FREQ=400_000
    time:   "time"


PUB main() | wkday, month

    setup()

' Uncomment the line below to set or change the date/time
'    set_date_time(11, 44, 00, AUG, 11, SUN, 24)

'   (this only needs to be done once as long as RTC remains powered afterwards)
'                hh, mm, ss, MMM, DD, WKDAY, YY

    repeat
        rtc.poll_rtc()
        { get weekday and month name strings from DAT table below }
        wkday := @wkday_name[(rtc.weekday() - 1) * 4]
        month := @month_name[(rtc.month() - 1) * 4]

        ser.pos_xy(0, 3)
        ser.printf(@"%s %d %s 20%d ", wkday, rtc.date(), month, rtc.year() )
        ser.printf(@"%02.2d:%02.2d:%02.2d", rtc.hours(), rtc.minutes(), rtc.seconds() )


PUB set_date_time(h, m, s, mmm, dd, wkday, yy)
' Update RTC's time
    rtc.set_hours(h)                             ' 00..23
    rtc.set_minutes(m)                           ' 00..59
    rtc.set_seconds(s)                           ' 00..59

    rtc.set_month(mmm)                           ' 01..12
    rtc.set_date(dd)                             ' 01..31
    rtc.set_weekday(wkday)                       ' 01..07
    rtc.set_year(yy)                             ' 00..99


DAT
    { map numbers to weekday and month names }
    wkday_name
            byte    "Sun", 0                    ' 1
            byte    "Mon", 0
            byte    "Tue", 0
            byte    "Wed", 0
            byte    "Thu", 0
            byte    "Fri", 0
            byte    "Sat", 0                    ' 7

    month_name
            byte    "Jan", 0                    ' 1
            byte    "Feb", 0
            byte    "Mar", 0
            byte    "Apr", 0
            byte    "May", 0
            byte    "Jun", 0
            byte    "Jul", 0
            byte    "Aug", 0
            byte    "Sep", 0
            byte    "Oct", 0
            byte    "Nov", 0
            byte    "Dec", 0                    ' 12


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( rtc.start() )
        ser.strln(@"RV3028 driver started")
    else
        ser.strln(@"RV3028 driver failed to start - halting")
        repeat


DAT
{
Copyright 2025 Jesse Burt

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

