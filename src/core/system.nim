import cpu
import interconnect
import memoryzone
import logging

type
  System* = object
    psxCpu: Cpu
    psxInterconnect: Interconnect

proc init*(this: var System) =
  var psxBios = new(MemoryZone)
  psxBios.loadFile("./assets/SCPH1001.BIN", BIOS_SIZE)
  psxBios.setStartAddr(BIOS_START_ADDR)
  psxBios.setMode(MemoryAccessMode.readOnly)
  info("Bios loaded")

  var memoryControl1 = new(MemoryZone)
  memoryControl1.fromMemory32([LTQ_MC_DDR_BASE_1_VALUE, LTQ_MC_DDR_BASE_2_VALUE])
  memoryControl1.setStartAddr(LTQ_MC_DDR_BASE_1)
  memoryControl1.setMode(MemoryAccessMode.noChange)

  var memoryControl2 = new(MemoryZone)
  memoryControl2.initEmpty(7 * WORD_SIZE)
  memoryControl2.setStartAddr(LTQ_MC_DDR_BASE_2 + 4)
  memoryControl2.setMode(MemoryAccessMode.readWrite)

  var ramSizeRegister = new(MemoryZone)
  ramSizeRegister.initEmpty(WORD_SIZE)
  ramSizeRegister.setStartAddr(RAM_SIZE_REG_ADDR)
  ramSizeRegister.setMode(readWrite)

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(psxBios)
  this.psxInterconnect.addZone(memoryControl1)
  this.psxInterconnect.addZone(memoryControl2)
  this.psxInterconnect.addZone(ramSizeRegister)
  info("System ready")

  this.psxCpu.init(this.psxInterconnect)

proc run*(this: var System) =
  try:
    while true:
      this.psxCpu.runNextInstr()
  except:
    this.psxCpu.printState()
    this.psxInterconnect.printState()
    raise