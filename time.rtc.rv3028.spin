{
    --------------------------------------------
    Filename: time.rtc.rv3028.spin
    Author: Jesse Burt
    Description: Driver for the RV3028 RTC
    Copyright (c) 2022
    Started Mar 13, 2021
    Updated Nov 27, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "time.rtc.common.spinh"

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

    { Automatic backup switchover modes }
    SWO_DIS         = %00
    SWO_DIRECT      = %01
    SWO_LEVEL       = %11

    { Interrupt active state }
    LOW             = 0
    HIGH            = 1

VAR

    long _clkdata_ok                            ' Clock data integrity

    byte _secs, _mins, _hours                   ' Vars to hold time
    byte _wkdays, _days, _months, _years        ' Order is important!

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef RV3028_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.rv3028"                     ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if (device_id{} == core#DEVID_RESP) ' validate device
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    bytefill(@_secs, 0, 7)
    _clkdata_ok := 0

PUB defaults{}
' Set factory defaults

PUB clk_data_ok{}: flag
' Flag indicating supply voltage ok/clock data integrity ok
'   Returns:
'       TRUE (-1): Supply voltage ok, clock data integrity guaranteed
'       FALSE (0): Supply voltage low, clock data integrity not guaranteed
    flag := 0
    readreg(core#STATUS, 1, @flag)
    _clkdata_ok := flag := ((flag & 1) == 0)

PUB backup_switchover(mode): curr_mode
' Set backup power supply automatic switchover function
'  *SWO_DIS (0): Switchover disabled
'   SWO_DIRECT (1): Switch when Vdd < Vbackup
'   SWO_LEVEL (3): Switch when Vdd < 2.0V AND Vbackup > 2.0V
'   NOTE: SWO_LEVEL (3) is recommended for use if the
'       backup power supply voltage is similar to the Propeller's,
'       to avoid unnecessary switching
    curr_mode := 0
    readreg(core#EE_BACKUP, 1, @curr_mode)
    case mode
        SWO_DIS, SWO_DIRECT, SWO_LEVEL:
            mode <<= core#BSM
        other:
            return ((curr_mode >> core#BSM) & core#BSM_BITS)

    mode := ((curr_mode & core#BSM_MASK) | mode)
    writereg(core#EE_BACKUP, 1, @mode)

PUB clkout_freq(freq): curr_freq
' Set frequency of CLKOUT pin, in Hz
'   Valid values: 0, 1, 32, 64, 1024, 8192, *32768
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core#EE_CLKOUT, 1, @curr_freq)
    case freq
        0, 1, 32, 64, 1024, 8192, 32768:
            freq := lookdownz(freq: 32768, 8192, 1024, 64, 32, 1, 0, 0)
        other:
            curr_freq &= core#FD_BITS
            return lookupz(curr_freq: 32768, 8192, 1024, 64, 32, 1, 0, 0)

    freq := ((curr_freq & core#FD_MASK & core#FD_MASK) | freq)
    writereg(core#EE_CLKOUT, 1, @freq)

PUB device_id{}: id
' Read device identification
    id := 0
    readreg(core#ID, 1, @id)

PUB int_clear(mask) | tmp
' Clear interrupts, using a bitmask
'   Valid values:
'       Bits: 5..0
'           5: Clock output interrupt flag
'           4: Backup switchover flag
'           3: Timer update flag
'           2: Timer countdown flag
'           1: Alarm flag
'           0: External event (EVI pin)/Automatic Backup switchover flag
'           For each bit, 0 to leave as-is, 1 to clear
'   Any other value is ignored
    case mask
        %000000..%111111:
            tmp := 0
            readreg(core#STATUS, 1, @tmp)
            mask := (mask ^ core#SINT_BITS) << core#SINT
            tmp := ((tmp & core#SINT_MASK) | mask)
            writereg(core#STATUS, 1, @tmp)
        other:
            return

PUB interrupt{}: flags
' Flag indicating one or more interrupts asserted
'   Bits: 5..0
'       5: Clock output interrupt flag
'       4: Backup switchover flag
'       3: Timer update flag
'       2: Timer countdown flag
'       1: Alarm flag
'       0: External event (EVI pin)/Automatic Backup switchover flag
    readreg(core#STATUS, 1, @flags)
    return (flags >> core#SINT) & core#SINT_BITS

PUB int_mask(mask): curr_mask
' Set interrupt mask
'   Valid values:
'       Bits: 4..0
'           4: Enable clock output on CLKOUT
'           3: Timer update event
'           2: Timer countdown event
'           1: Alarm event
'           0: External event (EVI pin)/Automatic Backup switchover event
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL2, 1, @curr_mask)
    case mask
        0..%11111:
            mask <<= core#EIE
        other:
            return ((curr_mask >> core#EIE) & core#IE_BITS)

    mask := ((curr_mask & core#IE_MASK) | mask)
    writereg(core#CTRL2, 1, @mask)

PUB int_pin_state(state): curr_state
' Set interrupt pin active state
'   LOW (0): /INT is active low
'   HIGH (1): /INT is active high
    curr_state := 0
    readreg(core#EVT_CTRL, 1, @curr_state)
    case state
        LOW, HIGH:
            state <<= core#EHL
        other:
            return (curr_state >> core#EHL) & 1

    state := ((curr_state & core#EHL_MASK) | state)
    writereg(core#EVT_CTRL, 1, @state)

PUB poll_rtc{}
' Read the time data from the RTC and store it in hub RAM
    readreg(core#SECONDS, 7, @_secs)

PUB reset{} | tmp
' Perform soft-reset
    tmp := 0

    readreg(core#CTRL2, 1, @tmp)
    tmp := (tmp & core#RESET_MASK) | 1
    writereg(core#CTRL2, 1, @tmp)               ' soft-reset

    tmp := 0

    readreg(core#STATUS, 1, @tmp)               ' clear the power-on/reset flag
    tmp &= core#PORF_MASK
    writereg(core#STATUS, 1, @tmp)

PUB set_date(d)
' Set current date/day of month
'   Valid values: 1..31
'   Any other value is ignored
    case d
        1..31:
            d := int2bcd(d)
            writereg(core#DATE, 1, @d)
        other:
            return

PUB set_hours(h)
' Set current hour
'   Valid values: 0..23
'   Any other value is ignored
    case h
        0..23:
            h := int2bcd(h)
            writereg(core#HOURS, 1, @h)
        other:
            return

PUB set_minutes(m)
' Set current minute
'   Valid values: 0..59
'   Any other value is ignored
    case m
        0..59:
            m := int2bcd(m)
            writereg(core#MINUTES, 1, @m)
        other:
            return

PUB set_month(m)
' Set current month
'   Valid values: 1..12
'   Any other value is ignored
    case m
        1..12:
            m := int2bcd(m)
            writereg(core#MONTH, 1, @m)
        other:
            return

PUB set_seconds(s)
' Set current second
'   Valid values: 0..59
'   Any other value is ignored
    case s
        0..59:
            s := int2bcd(s)
            writereg(core#SECONDS, 1, @s)
        other:
            return

PUB set_weekday(w)
' Set day of week
'   Valid values: 1..7
'   Any other value is ignored
    case w
        1..7:
            w := int2bcd(w-1)
            writereg(core#WKDAY, 1, @w)
        other:
            return

PUB set_year(y)
' Set 2-digit year
'   Valid values: 0..99
'   Any other value is ignored
    case y
        0..99:
            y := int2bcd(y)
            writereg(core#YEAR, 1, @y)
        other:
            return

PUB set_timer(val): curr_val
' Set countdown timer value
'   Valid values: 0..4095 (clamped to range)
    val := (0 #> val <# 4095)
    writereg(core#TIMER_LSB, 2, @val)

PUB timer{}: t
' Get currently set value of countdown timer
'   NOTE: This returns the value set by set_timer(). For the current remaining time,
'       use timer_remaining()
    t := 0
    readreg(core#TIMER_LSB, 2, @t)
    return (t & core#TIMER_MASK)

PUB timer_clk_freq(freq): curr_freq
' Set timer source clock frequency, in Hz
'   Valid values:
'       1_60 (1/60Hz), 1, 64, *4096
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core#CTRL1, 1, @curr_freq)
    case freq
        1_60, 1, 64, 4096:
            freq := lookdownz(freq: 4096, 64, 1, 1_60)
        other:
            curr_freq &= core#TD_BITS
            return lookupz(curr_freq: 4096, 64, 1, 1_60)

    freq := ((curr_freq & core#TD_MASK) | freq)
    writereg(core#CTRL1, 1, @freq)

PUB timer_ena(state): curr_state
' Enable countdown timer
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#TE
        other:
            return ((curr_state >> core#TE) & 1) == 1

    state := ((curr_state & core#TE_MASK) | state)
    writereg(core#CTRL1, 1, @state)

PUB timer_remaining{}: t
' Countdown timer time remaining
'   Returns: u12
    readreg(core#TMRSTAT_LSB, 2, @t)
    t &= core#TIMER_MASK

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $00..$3F:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:                                  ' invalid reg_nr
            return

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $00..$2A, $2C..$3F:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_lsbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return


DAT
{
Copyright 2022 Jesse Burt

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

