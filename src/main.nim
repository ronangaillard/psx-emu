import logging
import core/system

var consoleLog = newConsoleLogger(fmtStr="[$time] - $levelname: ")
addHandler(consoleLog)

info("Welcome to the nim psx emulator")

var psx = System()
psx.init()
