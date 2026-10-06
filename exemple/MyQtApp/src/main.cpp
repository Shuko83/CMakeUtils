#include <QCoreApplication>
#include <QString>
#include <QTextStream>

#include <string_view>

#include "MyQtApp_info.h"
#include "MySharedLib.h"
#include "MyStaticLib.h"

namespace
{
QString toQString(std::string_view text)
{
    return QString::fromUtf8(text.data(), static_cast<qsizetype>(text.size()));
}
} // namespace

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(toQString(MyQtAppInfo::name));
    QCoreApplication::setApplicationVersion(toQString(MyQtAppInfo::version));
    QCoreApplication::setOrganizationName(toQString(MyQtAppInfo::organization));
    QCoreApplication::setOrganizationDomain(toQString(MyQtAppInfo::organizationDomain));

    QTextStream out(stdout);
    out << QString("static = %1\nshared = %2\n").arg(myStaticValue()).arg(mySharedValue());
    out << toQString(MyQtAppInfo::about) << '\n';
    return 0;
}
