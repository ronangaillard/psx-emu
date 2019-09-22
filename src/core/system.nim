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

  var cacheControl = new(MemoryZone)
  cacheControl.initEmpty(WORD_SIZE)
  cacheControl.setStartAddr(CACHE_CONTROL_ADDR)
  cacheControl.setMode(readWrite)

  # Sound
  var spu = new(MemoryZone)
  spu.initEmpty(SPU_REGISTER_SIZE)
  spu.setStartAddr(SPU_REGISTER_ADDR)
  spu.setMode(readWrite)

  var ram = new(MemoryZone)
  ram.initEmpty(RAM_SIZE)
  ram.setStartAddr(RAM_START_ADDR)
  ram.setMode(readWrite)

  # Expansion port
  var expansion1 = new(MemoryZone)
  expansion1.setStartAddr(EXPANSION1_ADDRESS)
  expansion1.fromMemory8([0xff.uint8])
  expansion1.setMode(readOnly)

  # For hardware debugging
  var expansion2 = new(MemoryZone)
  expansion2.initEmpty(EXPANSION2_SIZE)
  expansion2.setStartAddr(EXPANSION2_ADDRESS)
  expansion2.setMode(readWrite)

  var interruptRegisters = new(MemoryZone)
  interruptRegisters.initEmpty(INTERRUPT_REGISTER_SIZE)
  interruptRegisters.setStartAddr(INTERRUPT_REGISTER_ADDRESS)
  interruptRegisters.setMode(readWrite)

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(psxBios)
  this.psxInterconnect.addZone(memoryControl1)
  this.psxInterconnect.addZone(memoryControl2)
  this.psxInterconnect.addZone(ramSizeRegister)
  this.psxInterconnect.addZone(cacheControl)
  this.psxInterconnect.addZone(ram)
  this.psxInterconnect.addZone(spu)
  this.psxInterconnect.addZone(expansion1)
  this.psxInterconnect.addZone(expansion2)
  this.psxInterconnect.addZone(interruptRegisters)
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