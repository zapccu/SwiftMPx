//
//  shim.c
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

#include "shim.h"

// Ändere 'mpfr_srcptr' zu 'void*' um die Swift-Typprüfung zu umgehen
void mpfr_helper_format(char *buffer, size_t capacity, int digits, const void *value) {    // Wir bauen den Format-String in C zusammen
    char format[32];
    snprintf(format, 32, "%%.%dRg", digits);
    
    // Hier ist der Aufruf in C erlaubt
    mpfr_snprintf(buffer, capacity, format, value);
}
