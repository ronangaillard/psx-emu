import strformat
import interconnect
import logging

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

proc init*(this: var Cpu) =
  this.pc = 0xbfc00000.uint32 # boot adress

proc printState*(this: Cpu) = 
  info("CPU State:")
  info(fmt"pc = {this.pc}")

proc load32(this: Cpu, address: uint32): uint32 =
  return 0

proc decodeAndExecute(this: Cpu, instruction: uint32) =
  let opcode: uint8 = ((instruction shl 26) and 0x3f).uint8
  info(fmt"opcode is {opcode}")

proc runNextInstr(this: var Cpu) =
  let pc: uint32 = this.pc
  let instruction: uint32 = this.load32(pc)

  this.pc = pc + 4

  this.decodeAndExecute(instruction)

