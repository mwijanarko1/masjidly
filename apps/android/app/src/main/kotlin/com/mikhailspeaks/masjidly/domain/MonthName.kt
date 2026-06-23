package com.mikhailspeaks.masjidly.domain

enum class MonthName(val rawValue: String) {
    JANUARY("january"),
    FEBRUARY("february"),
    MARCH("march"),
    APRIL("april"),
    MAY("may"),
    JUNE("june"),
    JULY("july"),
    AUGUST("august"),
    SEPTEMBER("september"),
    OCTOBER("october"),
    NOVEMBER("november"),
    DECEMBER("december"),
    ;

    companion object {
        fun from(monthNumber: Int): MonthName? = when (monthNumber) {
            1 -> JANUARY
            2 -> FEBRUARY
            3 -> MARCH
            4 -> APRIL
            5 -> MAY
            6 -> JUNE
            7 -> JULY
            8 -> AUGUST
            9 -> SEPTEMBER
            10 -> OCTOBER
            11 -> NOVEMBER
            12 -> DECEMBER
            else -> null
        }
    }
}
