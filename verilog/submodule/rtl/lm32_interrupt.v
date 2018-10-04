//   ==================================================================
//   >>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
//   ------------------------------------------------------------------
//   Copyright (c) 2006-2011 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
//   ------------------------------------------------------------------
//
//   IMPORTANT: THIS FILE IS AUTO-GENERATED BY THE LATTICEMICO SYSTEM.
//
//   Permission:
//
//      Lattice Semiconductor grants permission to use this code
//      pursuant to the terms of the Lattice Semiconductor Corporation
//      Open Source License Agreement.
//
//   Disclaimer:
//
//      Lattice Semiconductor provides no warranty regarding the use or
//      functionality of this code. It is the user's responsibility to
//      verify the user's design for consistency and functionality through
//      the use of formal verification methods.
//
//   --------------------------------------------------------------------
//
//                  Lattice Semiconductor Corporation
//                  5555 NE Moore Court
//                  Hillsboro, OR 97214
//                  U.S.A
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                         503-286-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
//   --------------------------------------------------------------------
//                         FILE DETAILS
// Project          : LatticeMico32
// File             : lm32_interrupt.v
// Title            : Interrupt logic
// Dependencies     : lm32_include.v
// Version          : 6.1.17
//                  : Initial Release
// Version          : 7.0SP2, 3.0
//                  : No Change
// Version          : 3.1
//                  : No Change
// =============================================================================

`include "lm32_include.v"

/////////////////////////////////////////////////////
// Module interface
/////////////////////////////////////////////////////

module lm32_interrupt (
    // ----- Inputs -------
    clk_i,
    rst_i,
    // From external devices
    interrupt,
    // From pipeline
    stall_x,
`ifdef CFG_DEBUG_ENABLED
    non_debug_exception,
    debug_exception,
`else
    exception,
`endif
    eret_q_x,
`ifdef CFG_DEBUG_ENABLED
    bret_q_x,
`endif
    csr,
    csr_write_data,
    csr_write_enable,
    // ----- Outputs -------
    interrupt_exception,
    // To pipeline
    csr_read_data
    );

/////////////////////////////////////////////////////
// Parameters
/////////////////////////////////////////////////////

parameter interrupts = `CFG_INTERRUPTS;         // Number of interrupts

/////////////////////////////////////////////////////
// Inputs
/////////////////////////////////////////////////////

input clk_i;                                    // Clock
input rst_i;                                    // Reset

input [interrupts-1:0] interrupt;               // Interrupt pins

input stall_x;                                  // Stall X pipeline stage

`ifdef CFG_DEBUG_ENABLED
input non_debug_exception;                      // Non-debug related exception has been raised
input debug_exception;                          // Debug-related exception has been raised
`else
input exception;                                // Exception has been raised
`endif
input eret_q_x;                                 // Return from exception
`ifdef CFG_DEBUG_ENABLED
input bret_q_x;                                 // Return from breakpoint
`endif

input [`LM32_CSR_RNG] csr;                      // CSR read/write index
input [`LM32_WORD_RNG] csr_write_data;          // Data to write to specified CSR
input csr_write_enable;                         // CSR write enable

/////////////////////////////////////////////////////
// Outputs
/////////////////////////////////////////////////////

output interrupt_exception;                     // Request to raide an interrupt exception
wire   interrupt_exception;

output [`LM32_WORD_RNG] csr_read_data;          // Data read from CSR
reg    [`LM32_WORD_RNG] csr_read_data;

/////////////////////////////////////////////////////
// Internal nets and registers
/////////////////////////////////////////////////////

`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
wire [interrupts-1:0] asserted;                 // Which interrupts are currently being asserted
//pragma attribute asserted preserve_signal true
`endif
wire [interrupts-1:0] interrupt_n_exception;

// Interrupt CSRs

reg ie;                                         // Interrupt enable
reg eie;                                        // Exception interrupt enable
`ifdef CFG_DEBUG_ENABLED
reg bie;                                        // Breakpoint interrupt enable
`endif
`ifdef CFG_LEVEL_SENSITIVE_INTERRUPTS
wire [interrupts-1:0] ip;                       // Interrupt pending
`else
reg [interrupts-1:0] ip;                        // Interrupt pending
`endif
reg [interrupts-1:0] im;                        // Interrupt mask

/////////////////////////////////////////////////////
// Combinational Logic
/////////////////////////////////////////////////////

// Determine which interrupts have occured and are unmasked
assign interrupt_n_exception = ip & im;

// Determine if any unmasked interrupts have occured
assign interrupt_exception = (|interrupt_n_exception) & ie;

// Determine which interrupts are currently being asserted or are already pending
`ifdef CFG_LEVEL_SENSITIVE_INTERRUPTS
assign ip = interrupt;
`else
assign asserted = ip | interrupt;
`endif

assign ie_csr_read_data = {{`LM32_WORD_WIDTH-3{1'b0}},
`ifdef CFG_DEBUG_ENABLED
                           bie,
`else
                           1'b0,
`endif
                           eie,
                           ie
                          };
assign ip_csr_read_data = ip;
assign im_csr_read_data = im;
generate
    if (interrupts > 1)
    begin
// CSR read
always @(*)
begin
    case (csr)
`ifdef CFG_MMU_ENABLED
    `LM32_CSR_PSW,
`endif
    `LM32_CSR_IE:  csr_read_data = {{`LM32_WORD_WIDTH-3{1'b0}},
`ifdef CFG_DEBUG_ENABLED
                                    bie,
`else
                                    1'b0,
`endif
                                    eie,
                                    ie
                                   };
    `LM32_CSR_IP:  csr_read_data = ip;
    `LM32_CSR_IM:  csr_read_data = im;
    default:       csr_read_data = {`LM32_WORD_WIDTH{1'bx}};
    endcase
end
    end
    else
    begin
// CSR read
always @(*)
begin
    case (csr)
    `LM32_CSR_IE:  csr_read_data = {{`LM32_WORD_WIDTH-3{1'b0}},
`ifdef CFG_DEBUG_ENABLED
                                    bie,
`else
                                    1'b0,
`endif
                                    eie,
                                    ie
                                   };
    `LM32_CSR_IP:  csr_read_data = ip;
    default:       csr_read_data = {`LM32_WORD_WIDTH{1'bx}};
    endcase
end
    end
endgenerate

/////////////////////////////////////////////////////
// Sequential Logic
/////////////////////////////////////////////////////

generate
    if (interrupts > 1)
    begin
// IE, IM, IP - Interrupt Enable, Interrupt Mask and Interrupt Pending CSRs
always @(posedge clk_i `CFG_RESET_SENSITIVITY)
begin
    if (rst_i == `TRUE)
    begin
        ie <= `FALSE;
        eie <= `FALSE;
`ifdef CFG_DEBUG_ENABLED
        bie <= `FALSE;
`endif
        im <= {interrupts{1'b0}};
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
        ip <= {interrupts{1'b0}};
`endif
    end
    else
    begin
        // Set IP bit when interrupt line is asserted
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
        ip <= asserted;
`endif
`ifdef CFG_DEBUG_ENABLED
        if (non_debug_exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            eie <= ie;
            ie <= `FALSE;
        end
        else if (debug_exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            bie <= ie;
            ie <= `FALSE;
        end
`else
        if (exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            eie <= ie;
            ie <= `FALSE;
        end
`endif
        else if (stall_x == `FALSE)
        begin
            if (eret_q_x == `TRUE)
                // Restore interrupt enable
                ie <= eie;
`ifdef CFG_DEBUG_ENABLED
            else if (bret_q_x == `TRUE)
                // Restore interrupt enable
                ie <= bie;
`endif
            else if (csr_write_enable == `TRUE)
            begin
                // Handle wcsr write
                if (   (csr == `LM32_CSR_IE)
`ifdef CFG_MMU_ENABLED
                    || (csr == `LM32_CSR_PSW)
`endif
                   )
                begin
                    ie <= csr_write_data[0];
                    eie <= csr_write_data[1];
`ifdef CFG_DEBUG_ENABLED
                    bie <= csr_write_data[2];
`endif
                end
                if (csr == `LM32_CSR_IM)
                    im <= csr_write_data[interrupts-1:0];
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
                if (csr == `LM32_CSR_IP)
                    ip <= asserted & ~csr_write_data[interrupts-1:0];
`endif
            end
        end
    end
end
    end
else
    begin
// IE, IM, IP - Interrupt Enable, Interrupt Mask and Interrupt Pending CSRs
always @(posedge clk_i `CFG_RESET_SENSITIVITY)
begin
    if (rst_i == `TRUE)
    begin
        ie <= `FALSE;
        eie <= `FALSE;
`ifdef CFG_DEBUG_ENABLED
        bie <= `FALSE;
`endif
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
        ip <= {interrupts{1'b0}};
`endif
    end
    else
    begin
        // Set IP bit when interrupt line is asserted
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
        ip <= asserted;
`endif
`ifdef CFG_DEBUG_ENABLED
        if (non_debug_exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            eie <= ie;
            ie <= `FALSE;
        end
        else if (debug_exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            bie <= ie;
            ie <= `FALSE;
        end
`else
        if (exception == `TRUE)
        begin
            // Save and then clear interrupt enable
            eie <= ie;
            ie <= `FALSE;
        end
`endif
        else if (stall_x == `FALSE)
        begin
            if (eret_q_x == `TRUE)
                // Restore interrupt enable
                ie <= eie;
`ifdef CFG_DEBUG_ENABLED
            else if (bret_q_x == `TRUE)
                // Restore interrupt enable
                ie <= bie;
`endif
            else if (csr_write_enable == `TRUE)
            begin
                // Handle wcsr write
                if (   (csr == `LM32_CSR_IE)
`ifdef CFG_MMU_ENABLED
                    || (csr == `LM32_CSR_PSW)
`endif
                   )
                begin
                    ie <= csr_write_data[0];
                    eie <= csr_write_data[1];
`ifdef CFG_DEBUG_ENABLED
                    bie <= csr_write_data[2];
`endif
                end
`ifndef CFG_LEVEL_SENSITIVE_INTERRUPTS
                if (csr == `LM32_CSR_IP)
                    ip <= asserted & ~csr_write_data[interrupts-1:0];
`endif
            end
        end
    end
end
    end
endgenerate

endmodule

