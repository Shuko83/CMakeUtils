#include <iostream>

#include "MySharedLib.h"
#include "MyStaticLib.h"

int main()
{
    std::cout << "static = " << myStaticValue() << '\n'
              << "shared = " << mySharedValue() << '\n';
    return 0;
}
