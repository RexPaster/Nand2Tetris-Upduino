# Assumes only SystemVerilog (.sv) files are used
# Format is:
#    Product : List of Dependencies (Use \ at the end of the line for line continuation)
#
# Types of products are:
#    *.rtl.json:  Simulation file
#    *.vcd:  Value Change Dump (signal trace)
#    *.ice40.svg:  Ice40 synthesis
#    *.aig.svg:  AIG synthesis
#    *.aig.png:  AIG synthesis
#    *.placed.svg:  Placement data/image
#    *.routed.svg:  Routing data/image
#    *.bin:  bitstream
#    *.edit: Open the preceding file for editing
#    *.riscv-sim: Simulate the file (using launch.json view; Must config launch.json)
#    *.ice40.dot: Ice40 synthesis in dot format
#    *.rom.txt: Convert a single .s file to assembly format for RISC-V ROM (Does not sanity check; Will remove any lines between <RM> and </RM> tags)
#    *.shell: Run a shell script (make, etc.); Requires a run="..." option to specify the command to run.
# Products still in alpha testing:
#    *.placed.svg : Placement data and file viewer (requires webserver be running to view)
#    *.router.svg : Router data and file viewer (requires webserver be running to view)
#
# A line preceding a target that starts with a comment can "override" the type of target or the label used in the task
#   With either/both label="..." or type="..." (Types include a dot for the extension, like .edit or .rtl.json)
#   A type of "edit" can be used to open the file in code.
#   A label that starts with an underscore (_) will be hidden in the task list (I.e., to hide intermediate tasks that don't need to be run directly)
#
# There are also global dependencies that can be used to launch common tasks independent of specific modules or projects:
#   The type="server" can be used to include a task for the FPGA server
#   The type="rebuild" can be used to include a task for rebuilding the tasks themselves (still need to be refreshed)

# label="FPGA Image Server" type="server"
server:

# # label="Rebuild Tasks" type="rebuild"
# rebuild:

# Not needed here, but no harm...
.PHONY: server rebuild

# Split design RTL sources from testbench sources.
TB_SOURCES := $(sort $(wildcard *_tb.sv))
RTL_SOURCES := top.sv $(sort $(filter-out top.sv $(TB_SOURCES),$(wildcard *.sv)))

# -----------------------------
# Simulation / Testbench
# -----------------------------

# label="top testbench verification"
products/top_tb.vcd: \
	$(RTL_SOURCES) \
	$(TB_SOURCES)

# label="Edit top.sv" type=".edit"
top.sv.edit:

# label="Simulate top.sv"
products/top.rtl.json: \
	$(RTL_SOURCES)

# -----------------------------
# Synthesis / AIG / ICE40 / Bitstream
# -----------------------------

# label="top AIG Mapping"
products/top.aig.svg: \
	$(RTL_SOURCES)

# label="top ICE40 Mapping"
products/top.ice40.svg: \
	$(RTL_SOURCES)

# label="top ICE40 Bitstream"
products/top.bin: \
	$(RTL_SOURCES) \
	top.pcf

# label="top Routing"
products/top.routed.svg: \
	$(RTL_SOURCES) \
	top.pcf

# label="Flash ROM (SPI)"
products/rom.flash.bin: \
	rom/rom.hack
