{
    --------------------------------------------
    Filename: core.con.rv3028.spin
    Author:
    Description:
    Copyright (c) 2021
    Started Mar 13, 2021
    Updated Mar 13, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 100_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $52 << 1                  ' 7-bit format slave address
    T_POR           = 1000                         ' startup time (usecs)

    DEVID_RESP      = $00                       ' device ID expected response

' Register definitions
    ID              = $28


PUB Null{}
' This is not a top-level object

