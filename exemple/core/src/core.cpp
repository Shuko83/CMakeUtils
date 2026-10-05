#include "core.h"

#include <QString>

int core() { return QString::number(CORE_VALUE).toInt(); }
