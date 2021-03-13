{
    --------------------------------------------
    Filename: time.rtc.rv3028.i2c.spin
    Author: Jesse Burt
    Description: Driver for the RV3028 RTC
    Copyright (c) 2021
    Started Mar 13, 2021
    Updated Mar 13, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR          = core#SLAVE_ADDR
    SLAVE_RD          = core#SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 100_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

' Automatic backup switchover modes
    SWO_DIS         = %00
    SWO_DIRECT      = %01
    SWO_LEVEL       = %11

VAR

    byte _secs, _mins, _hours                   ' Vars to hold time
    byte _wkdays, _days, _months, _years        ' Order is important!

    byte _clkdata_ok                            ' Clock data integrity

OBJ

' choose an I2C engine below
    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
    core: "core.con.rv3028"                     ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if i2c.present(SLAVE_WR)            ' test device bus presence
                if deviceid{} == core#DEVID_RESP' validate device
                    return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults
{
PUB ClockDataOk{}: flag
' Flag indicating battery voltage ok/clock data integrity ok
'   Returns:
'       TRUE (-1): Battery voltage ok, clock data integrity guaranteed
'       FALSE (0): Battery voltage low, clock data integrity not guaranteed
    pollrtc{}
    return _clkdata_ok == 0
}
PUB BackupSwitchover(mode): curr_mode
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

PUB ClockOutFreq(freq): curr_freq
' Set frequency of CLKOUT pin, in Hz
'   Valid values: 0, 1, 32, 64, 1024, 8192, 32768
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

PUB Date(ptr_date)

PUB DeviceID{}: id
' Read device identification
    readreg(core#ID, 1, @id)

PUB Day(d): curr_day
' Set day of month
'   Valid values: 1..31
'   Any other value returns the last read current day
    case d
        1..31:
            d := int2bcd(d)
            writereg(core#DATE, 1, @d)
        other:
            return bcd2int(_days)

PUB Hours(hr): curr_hr
' Set hours
'   Valid values: 0..23
'   Any other value returns the last read current hour
    case hr
        0..23:
            hr := int2bcd(hr)
            writereg(core#HOURS, 1, @hr)
        other:
            return bcd2int(_hours)
{
PUB IntClear(mask) | tmp
' Clear interrupts, using a bitmask
'   Valid values:
'       Bits: 1..0
'           1: clear alarm interrupt
'           0: clear timer interrupt
'           For each bit, 0 to leave as-is, 1 to clear
'   Any other value is ignored
    case mask
        %01, %10, %11:
            readreg(core#CTRLSTAT2, 1, @tmp)
            mask := (mask ^ %11) << core#TF     ' Reg bits are inverted
            tmp |= mask
            tmp &= core#CTRLSTAT2_MASK
            writereg(core#CTRLSTAT2, 1, @tmp)
        other:
            return

PUB Interrupt{}: flags
' Flag indicating one or more interrupts asserted
    readreg(core#CTRLSTAT2, 1, @flags)
    flags := (flags >> core#TF) & core#IF_BITS
}
PUB IntMask(mask): curr_mask
' Set interrupt mask
'   Valid values:
'       Bits: 5..0
'           5: Enable time stamp
'           4: Clock output on CLKOUT
'           3: Timer update event
'           2: Timer countdown event
'           1: Alarm event
'           0: External event (EVI pin)/Automatic Backup switchover event
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL2, 1, @curr_mask)
    case mask
        0..%111111:
            mask <<= core#EIE
        other:
            return ((curr_mask >> core#EIE) & core#IE_BITS)

    mask := ((curr_mask & core#IE_MASK) | mask)
    writereg(core#CTRL2, 1, @mask)
{
PUB IntPinState(state): curr_state
' Set interrupt pin active state
'   WHEN_TF_ACTIVE (0): /INT is active when timer interrupt asserted
'   INT_PULSES (1): /INT pulses at rate set by TimerClockFreq()
    curr_state := 0
    readreg(core#CTRLSTAT2, 1, @curr_state)
    case state
        WHEN_TF_ACTIVE, INT_PULSES:
        other:
            return (curr_state >> core#TI_TP) & 1

    state := ((curr_state & core#TI_TP_MASK) | state) & core#CTRLSTAT2_MASK
    writereg(core#CTRLSTAT2, 1, @state)
}
PUB Month(m): curr_month
' Set month
'   Valid values: 1..12
'   Any other value returns the last read current month
    case m
        1..12:
            m := int2bcd(m)
            writereg(core#MONTH, 1, @m)
        other:
            return bcd2int(_months)

PUB Minutes(minute): curr_min
' Set minutes
'   Valid values: 0..59
'   Any other value returns the last read current minute
    case minute
        0..59:
            minute := int2bcd(minute)
            writereg(core#MINUTES, 1, @minute)
        other:
            return bcd2int(_mins)

PUB PollRTC{}
' Read the time data from the RTC and store it in hub RAM
' Update the clock integrity status bit from the RTC
    readreg(core#SECONDS, 7, @_secs)
'    _clkdata_ok := (_secs >> core#VL) & 1       ' Clock integrity bit

PUB Seconds(second): curr_sec
' Set seconds
'   Valid values: 0..59
'   Any other value polls the RTC and returns the current second
    case second
        0..59:
            second := int2bcd(second)
            writereg(core#SECONDS, 1, @second)
        other:
            return bcd2int(_secs)
{
PUB Timer(val): curr_val
' Set countdown timer value
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
'   NOTE: The countdown period in seconds is equal to
'       Timer() / TimerClockFreq()
'       e.g., if Timer() is set to 255, and TimerClockFreq() is set to 1,
'       the period is 255 seconds
    case val
        0..255:
            writereg(core#TIMER, 1, @val)
        other:
            repeat 2                                    ' Datasheet recommends
                curr_val := 0                           ' 2 reads to check for
                readreg(core#TIMER, 1, @curr_val.byte[0]) ' consistent results
                readreg(core#TIMER, 1, @curr_val.byte[1]) '
                if curr_val.byte[0] == curr_val.byte[1]
                    curr_val.byte[1] := 0
                    quit
            return curr_val & core#TIMER_MASK
}
PUB TimerClockFreq(freq): curr_freq
' Set timer source clock frequency, in Hz
'   Valid values:
'       1_60 (1/60Hz), 1, 64, 4096
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

PUB TimerEnabled(state): curr_state
' Enable countdown timer
'   Valid values: TRUE (-1 or 1), FALSE (0)
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

PUB Weekday(wkday): curr_wkday
' Set day of week
'   Valid values: 1..7
'   Any other value returns the last read current day of week
    case wkday
        1..7:
            wkday := int2bcd(wkday-1)
            writereg(core#WKDAY, 1, @wkday)
        other:
            return bcd2int(_wkdays) + 1

PUB Year(yr): curr_yr
' Set 2-digit year
'   Valid values: 0..99
'   Any other value returns the last read current year
    case yr
        0..99:
            yr := int2bcd(yr)
            writereg(core#YEAR, 1, @yr)
        other:
            return bcd2int(_years)

PRI bcd2int(bcd): int
' Convert BCD (Binary Coded Decimal) to integer
    return ((bcd >> 4) * 10) + (bcd // 16)

PRI int2bcd(int): bcd
' Convert integer to BCD (Binary Coded Decimal)
    return ((int / 10) << 4) + (int // 10)

PUB Reset{}
' Reset the device

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $00..$3F:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)

' choose the block below appropriate to your device
    ' write LSByte to MSByte
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
    '
        other:                                  ' invalid reg_nr
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $00..$2A, $2C..$3F:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

' choose the block below appropriate to your device
    ' write LSByte to MSByte
            i2c.wrblock_lsbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
