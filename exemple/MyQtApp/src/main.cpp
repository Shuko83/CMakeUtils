#include <QString>
#include <QTextStream>

#include "MySharedLib.h"
#include "MyStaticLib.h"

int main()
{
    QTextStream out(stdout);
    out << QString("static = %1\nshared = %2\n").arg(myStaticValue()).arg(mySharedValue());
    return 0;
}
