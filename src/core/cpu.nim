import strformat
import interconnect
import logging
import opcodes
import tables
import memoryzone
import terminal

type UnknownOpcode = Exception
type UnknownRegister = Exception

# Cpu utils
## Get opcode
proc op(instruction: uint32): uint8 = (instruction shr 26).uint8
## Get t
proc t(instruction: uint32): uint8 = ((instruction shr 16) and 0x1f).uint8
## Get s
proc s(instruction: uint32): uint8 = ((instruction shr 21) and 0x1f).uint8
## Get d
proc d(instruction: uint32): uint8 = ((instruction shr 11) and 0x1f).uint8
## Get h
proc h(instruction: uint32): uint8 = ((instruction shr 6) and 0x1f).uint8
## Get subfunction (bit [5:0]
proc subfunction(instruction: uint32): uint8 = (instruction and 0x1f).uint8
## Get immediate value
proc imm(instruction: uint32): uint16 = (instruction and 0xffff).uint16
## Get immediate value signed extended
proc immSe(instruction: uint32): uint32 = 
  result = (instruction and 0xffff).uint32
  if (result and 0x8000) == 0x8000:
    result = result or 0xffff0000.uint32
## Get immediate value for jump
proc immJump(instruction: uint32): uint32 = (instruction and 0x3ffffff).uint32

type
  Cpu* = object
    interco: Interconnect
    generalRegs: array[32, uint32]
    pc: uint32
    nextPc: uint32
    ir: uint32
    hi: uint32
    lo: uint32 
    # General purpose registers
    regs: array[32, uint32]
    # General purpose regs array used to emulate
    # the load delay slot in MIPS processors
    # They hold the output of the current instruction
    loadDelayRegs: array[32, uint32]
    # Load initiated by current instruction (reg index, value)
    load: (uint8, uint32)


    # Coprocessor registers
    sr: uint32

    instructionsTable: Table[int, proc(this: var Cpu, instruction: uint32) {.nimcall.}]

    # This is used for instructions with opcode = 0
    subInstructionsTable: Table[int, proc(this: var Cpu, instruction: uint32) {.nimcall.}]

proc setPc(this: var Cpu, pc: uint32) =
  this.pc = pc
  this.nextPc = pc + WORD_SIZE

proc setReg(this: var Cpu, regIndex: uint8, value: uint32) =
  if regIndex >= 32.uint32:
    raise newException(UnknownRegister, fmt"Register {regIndex} does not exist, but trying to write to it")

  # reg 0 is the zero register
  if regIndex == 0:
    return

  this.loadDelayRegs[regIndex] = value

proc printState*(this: Cpu) = 
  var cpuState = "CPU State:\n"
  cpuState &= fmt"pc = {this.pc:#x}" & "\n"
  for i in 0 .. <32:
    cpuState &= fmt"reg[{i}] = {this.regs[i]:#x}" & "\n"

  info(cpuState)

proc branch(this: var Cpu, offset: uint32) =
  # Offset is shifted left to get aligned addresses
  let offset = offset shl 2

  this.nextPc = this.pc + offset

# Instructions
proc instrLui(this: var Cpu, instruction: uint32) =
  let v = instruction.imm.uint32 shl 16
  this.setReg(instruction.t, v)

proc instrOri(this: var Cpu, instruction: uint32) =
  let regIndex = instruction.t
  let v = this.regs[regIndex] or instruction.imm

  this.setReg(regIndex, v)

proc instrSw(this: var Cpu, instruction: uint32) =
  if (this.sr and 0x10000) != 0:
    notice("Ignoring store when cache is isolated")
    return

  let i = instruction.immSe
  let t = instruction.t
  let s = instruction.s

  let address = this.regs[s] + i
  let v = this.regs[t]

  this.interco.store32(address, v)

proc instrSll(this: var Cpu, instruction: uint32) =
  let h = instruction.h
  let t = instruction.t
  let d = instruction.d

  let v = this.regs[t] shl h

  this.setReg(d, v)

proc instrZero(this: var Cpu, instruction: uint32) =
  info(fmt"Decoding sub {instruction:#x}")
  let subFunction = instruction.subfunction.int

  if not this.subInstructionsTable.contains(subfunction):
    raise newException(UnknownOpcode, fmt"Subfunction {instruction.subfunction:#b} not supported")

  this.subInstructionsTable[subFunction](this, instruction)

proc instrAddiu(this: var Cpu, instruction: uint32) =
  let i = instruction.immSe
  let t = instruction.t
  let s = instruction.s

  let v = this.regs[s] + i

  this.setReg(t, v)

proc instrJ(this: var Cpu, instruction: uint32) =
  let i = instruction.immJump
  this.nextPc = (this.pc and 0xf0000000.uint32) or (i shl 2)

proc instrOr(this: var Cpu, instruction: uint32) =
  let d = instruction.d
  let s = instruction.s
  let t = instruction.t
  let v = this.regs[s] or this.regs[t]

  this.setReg(d, v)

proc instrCop0(this: var Cpu, instruction: uint32) =
  let cpu_r = instruction.t
  let cop_r = instruction.d

  let v = this.regs[cpu_r]

  case cop_r:
    of 12:
      this.sr = v
    of 13:
      if v != 0:
        raise newException(Exception, "Unhandle write to CAUSE register")
    of 3, 5, 6, 7, 9, 11:
      if v != 0:
        raise newException(Exception, "Unhandle write to coprocessor register")
    else:
      raise newException(Exception, fmt"Unknown coprocessor register : {cop_r}")

proc instrBne(this: var Cpu, instruction: uint32) =
  let i = instruction.immSe
  let s = instruction.s
  let t = instruction.t

  if this.regs[s] != this.regs[t]:
    this.branch(i)

proc instrAddi(this: var Cpu, instruction: uint32) =
  let i = instruction.immSe
  let t = instruction.t
  let s = this.regs[instruction.s]
  var v: uint32

  try:
    v = s + i
  except:
    raise newException(Exception, "Overflow in ADD")

  this.setReg(t, v)

proc instrLw(this: var Cpu, instruction: uint32) =
  if (this.sr and 0x10000) != 0:
     notice("Ignoring store when cache is isolated")
     return
    
  let i = instruction.immSe
  let t = instruction.t
  let s = instruction.s
  let address = this.regs[s] + i

  let v = this.interco.load32(address)

  this.load = (t, v)

proc instrSltu(this: var Cpu, instruction: uint32) =
  let d = instruction.d
  let s = instruction.s
  let t = instruction.t

  var v: uint32
  if this.regs[s] < this.regs[t]:
    v = 1
  else:
    v = 0

  this.setReg(d, v)

proc instrAddu(this: var Cpu, instruction: uint32) =
  let s = instruction.s
  let t = instruction.t
  let d = instruction.d

  let v = this.regs[s] + this.regs[t]

  this.setReg(d, v)

proc instrSh(this: var Cpu, instruction: uint32) =
  if (this.sr and 0x10000) != 0:
     notice("Ignoring store when cache is isolated")
     return
    
  let i = instruction.immSe
  let t = instruction.t
  let s = instruction.s

  let address = this.regs[s] + i
  let v = this.regs[t].uint16

  this.interco.store16(address, v)
# End of instruction

proc init*(this: var Cpu, interco: Interconnect) =
  this.interco = interco
  this.setPc(BIOS_START_ADDR)
  this.sr = 0
  this.load = (0.uint8, 0.uint32)

  # Fill regs with garbage data
  for i in 1 .. <32:
    this.setReg(i.uint8, 0xdeadbeef.uint32)

  # Set instruction table
  # Maybe we should set this as const or move its declaration elsewhere
  this.instructionsTable = {
    OPCODE_LUI: instrLui,
    OPCODE_ORI: instrOri,
    OPCODE_SW: instrSw,
    OPCODE_ZERO: instrZero,
    OPCODE_ADDIU: instrAddiu,
    OPCODE_J: instrJ,
    OPCODE_COP0: instrCop0,
    OPCODE_BNE: instrBne,
    OPCODE_ADDI: instrAddi,
    OPCODE_LW: instrLw,
    OPCODE_SH: instrSh
  }.toTable

  this.subInstructionsTable = {
    SUBFUNCTION_SLL: instrSll,
    SUBFUNCTION_OR: instrOr,
    SUBFUNCTION_SLTU: instrSltu,
    SUBFUNCTION_ADDU: instrAddu
   }.toTable

proc decodeAndExecute(this: var Cpu, instruction: uint32) =
  info(fmt"Decoding {instruction:#x} @{this.pc - 2 * WORD_SIZE:#x}")
  let opcode = instruction.op.int

  if not this.instructionsTable.contains(opcode):
    raise newException(UnknownOpcode, fmt"Opcode {instruction.op:#b} not supported")

  this.instructionsTable[opcode](this, instruction)

proc runNextInstr*(this: var Cpu) =
  let instruction: uint32 = this.interco.load32(this.pc)

  this.pc = this.nextPc
  this.nextPc = this.pc + WORD_SIZE

  # Execute the pending load
  let (reg, value) = this.load
  this.setReg(reg.uint8, value)

  # Reset the load
  this.load = (0.uint8 ,0.uint32)

  this.decodeAndExecute(instruction)

  this.regs = this.loadDelayRegs
