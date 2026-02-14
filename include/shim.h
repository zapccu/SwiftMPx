//
//  shim.h
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

#ifndef shim_h
#define shim_h

#include <mpfr.h>
#include <stdio.h>

// Wrapper for variadic argument function
// Ändere 'mpfr_srcptr' zu 'void*' um die Swift-Typprüfung zu umgehen
void mpfr_helper_format(char *buffer, size_t capacity, int digits, const void *value);

#endif
