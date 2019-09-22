const OPCODE_LUI* = 0b001111
const OPCODE_ORI* = 0b001101
const OPCODE_SW*  = 0b101011 # Store Word
const OPCODE_ZERO* = 0b000000
const OPCODE_ADDIU* = 0b001001
const OPCODE_J* = 0b000010
const OPCODE_COP0* = 0b010000
const OPCODE_BNE* = 0b000101
const OPCODE_ADDI* = 0b001000
const OPCODE_LW* = 0b100011
const OPCODE_SH* = 0b101001
const OPCODE_JAL* = 0b000011
const OPCODE_ANDI* = 0b001100
const OPCODE_SB* = 0b101000
const OPCODE_LB* = 0b100000
const OPCODE_BEQ* = 0b000100

const SUBFUNCTION_SLL* = 0b00000
const SUBFUNCTION_OR* = 0b00101
const SUBFUNCTION_SLTU* = 0b01011 
const SUBFUNCTION_ADDU* = 0b00001
const SUBFUNCTION_JR* = 0b01000
const SUBFUNCTION_AND* = 0b00100