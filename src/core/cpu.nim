import strformat
import interconnect
import logging
import opcodes
import tables

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
  if (result and 0x8000).bool:
    result = result or 0xffff0000.uint32
## Get immediate value for jump
proc immJump(instruction: uint32): uint32 = (instruction and 0x3ffffff).uint32

type
  Cpu* = object
    interco: Interconnect
    generalRegs: array[32, uint32]
    pc: uint32
    ir: uint32
    hi: uint32
    lo: uint32 
    # General purpose registers
    regs: array[32, uint32]

    # Coprocessor registers
    badvaddr: uint32
    status: uint32
    cause: uint32
    epc: uint32

    # Virtual memory registers
    tlb: uint32
    index: uint32
    random: uint32
    context: uint32
    entryhi: uint32
    entrylo: uint32

    instructionsTable: Table[int, proc(this: var Cpu, instruction: uint32) {.nimcall.}]

proc setReg(this: var Cpu, regIndex: uint8, value: uint32) =
  if regIndex >= 32.uint32:
    raise newException(UnknownRegister, fmt"Register {regIndex} does not exist, but trying to write to it")

  # reg 0 is the zero register
  if regIndex == 0:
    return

  this.regs[regIndex] = value

proc printState*(this: Cpu) = 
  var cpuState = "CPU State:\n"
  cpuState &= fmt"pc = {this.pc}" & "\n"
  for i in 0 .. <32:
    cpuState &= fmt"reg[{i}] = {this.regs[i]:#x}" & "\n"

  info(cpuState)

# Instructions
proc instrLui(this: var Cpu, instruction: uint32) =
  let v = instruction.imm.uint32 shl 16
  this.setReg(instruction.t, v)

proc instrOri(this: var Cpu, instruction: uint32) =
  let regIndex = instruction.t
  let v = this.regs[regIndex] or instruction.imm

  this.setReg(regIndex, v)

proc instrSw(this: var Cpu, instruction: uint32) =
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
  if instruction.subfunction == SUBFUNCTION_SLL:
    this.instrSll(instruction)
  else:
    raise newException(UnknownOpcode, fmt"Opcode {instruction.op:#b} not supported")

proc instrAddiu(this: var Cpu, instruction: uint32) =
  let i = instruction.immSe
  let t = instruction.t
  let s = instruction.s

  let v = this.regs[s] + i

  this.setReg(t, v)

proc instrJ(this: var Cpu, instruction: uint32) =
  let i = instruction.immJump
  this.pc = (this.pc and 0xf0000000.uint32) or (i shl 2)
# End of instruction

proc init*(this: var Cpu, interco: Interconnect) =
  this.interco = interco
  this.pc = 0xbfc00000.uint32 # boot adress

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
    OPCODE_J: instrJ
  }.toTable

proc decodeAndExecute(this: var Cpu, instruction: uint32) =
  info(fmt"Decoding {instruction:#b}")
  let opcode = instruction.op.int

  if not this.instructionsTable.contains(opcode):
    raise newException(UnknownOpcode, fmt"Opcode {instruction.op:#b} not supported")

  this.instructionsTable[opcode](this, instruction)

proc runNextInstr*(this: var Cpu) =
  let instruction: uint32 = this.interco.load32(this.pc)

  this.pc = this.pc + 4

  this.decodeAndExecute(instruction)


