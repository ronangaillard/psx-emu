import strformat
import interconnect
import logging

type UnknownOpcode = Exception

type
  Cpu* = object
    interco: Interconnect
    generalRegs: array[32, uint32]
    pc: uint32
    ir: uint32
    hi: uint32
    lo: uint32 

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

proc init*(this: var Cpu, interco: Interconnect) =
  this.interco = interco
  this.pc = 0xbfc00000.uint32 # boot adress

proc printState*(this: Cpu) = 
  info("CPU State:")
  info(fmt"pc = {this.pc}")

proc decodeAndExecute(this: Cpu, instruction: uint32) =
  info(fmt"Intruction in {instruction:#x}")
  let opcode: uint8 = ((instruction shl 26) and 0x3f).uint8
  raise newException(UnknownOpcode, fmt"Opcode {opcode} not supported")

proc runNextInstr*(this: var Cpu) =
  let instruction: uint32 = this.interco.load32(this.pc)

  this.pc = this.pc + 4

  this.decodeAndExecute(instruction)

