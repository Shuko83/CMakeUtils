// Copyright (C) 2026 Fabien Di Grande
// SPDX-License-Identifier: MPL-2.0

#include <iostream>

#include "MySharedLib.h"
#include "MyStaticLib.h"

int main()
{
    std::cout << "static = " << myStaticValue() << '\n'
              << "shared = " << mySharedValue() << '\n';
    return 0;
}
