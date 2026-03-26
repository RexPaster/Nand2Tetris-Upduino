# Based on https://tech.davis-hansson.com/p/make/
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
# Assume a recent version of GNU Make
.RECIPEPREFIX = >

MAKEFILE_PATH = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
IMAGES_DIR := $(MAKEFILE_PATH)/../images

# Project-wide settings loaded from settings.json in repository root.
SETTINGS_JSON ?= settings.json
BUILD_PRESET_FROM_SETTINGS := $(shell python3 -c 'import json,pathlib; p=pathlib.Path("$(SETTINGS_JSON)"); cfg=json.loads(p.read_text()) if p.exists() else {}; print(cfg.get("build_preset","fast"))' 2>/dev/null || echo fast)
USE_SPI_FLASH_ROM := $(shell python3 -c 'import json,pathlib; p=pathlib.Path("$(SETTINGS_JSON)"); cfg=json.loads(p.read_text()) if p.exists() else {}; v=str(cfg.get("use_spi_flash_rom",1)).strip().lower(); print(1 if v in ("1","true","yes","on") else 0)' 2>/dev/null || echo 1)
SIM_USE_SPI_FLASH_ROM := $(shell python3 -c 'import json,pathlib; p=pathlib.Path("$(SETTINGS_JSON)"); cfg=json.loads(p.read_text()) if p.exists() else {}; v=str(cfg.get("sim_use_spi_flash_rom",1)).strip().lower(); print(1 if v in ("1","true","yes","on") else 0)' 2>/dev/null || echo 1)

# ROM flashing settings are configurable from settings.json.
ROM_FLASH_OFFSET_FROM_SETTINGS := $(shell python3 -c 'import json,pathlib; p=pathlib.Path("$(SETTINGS_JSON)"); cfg=json.loads(p.read_text()) if p.exists() else {}; print(cfg.get("rom_flash_offset","0x200000"))' 2>/dev/null || echo 0x200000)
ROM_FLASH_IMAGE_FROM_SETTINGS := $(shell python3 -c 'import json,pathlib; p=pathlib.Path("$(SETTINGS_JSON)"); cfg=json.loads(p.read_text()) if p.exists() else {}; print(cfg.get("rom_flash_image","rom/rom.hack"))' 2>/dev/null || echo rom/rom.hack)

ICEPROG ?= iceprog
ROM_FLASH_OFFSET ?= $(ROM_FLASH_OFFSET_FROM_SETTINGS)
ROM_HACK_IMAGE ?= $(ROM_FLASH_IMAGE_FROM_SETTINGS)
ROM_SPI_IMAGE ?= products/rom.spi.bin


# Build tuning knobs
# Set BUILD_PRESET to one of:

#   fast   : quickest iteration
#   better : higher quality of results (slower)
#   best   : highest-effort QoR (slowest)
#
# Examples:

#   make BUILD_PRESET=fast products/top.bin
#   make BUILD_PRESET=better products/top.bin
#   make BUILD_PRESET=best products/top.bin
BUILD_PRESET ?= $(BUILD_PRESET_FROM_SETTINGS)
NEXTPNR_THREADS ?= $(shell nproc)

ifeq ($(BUILD_PRESET),better)
YOSYS_ICE40_FLAGS = -abc9 -noflatten
NEXTPNR_FLAGS = --placer sa --opt-timing
else ifeq ($(BUILD_PRESET),best)
YOSYS_ICE40_FLAGS = -abc9
NEXTPNR_FLAGS = --placer sa --opt-timing
else
YOSYS_ICE40_FLAGS = -dff -noabc9 -noflatten
NEXTPNR_FLAGS = --placer heap
endif


# Dummy rule to force a rebuild
FORCE: ;
.PHONY: FORCE

# Default to nothing
default:

# Include the dependencies file
# If there's not a dependencies.mk file, stop with an error
ifeq ($(wildcard dependencies.mk),)
  $(error No dependencies.mk file found)
else
  include dependencies.mk
endif

# If top.sv is among HDL dependencies, use module "top" as hierarchy root.
YOSYS_HIERARCHY = $(if $(filter top.sv,$(notdir $(filter %.sv,$^))),hierarchy -top top,hierarchy -auto-top)
YOSYS_TOP_CHPARAM = $(if $(filter top.sv,$(notdir $(filter %.sv,$^))),chparam -set USE_SPI_FLASH_ROM $(USE_SPI_FLASH_ROM) top;,)

#### HDL Build Rules (Essentially a shell script) ####


%.rtl.json:
>     @echo "Building $(filter %.top.sv, $^)"
>     yosys -p "read_verilog -sv $^ ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); proc; opt; fsm -expand; memory -nomap; wreduce -memx; opt_clean;" -o $@


## Parsing out "top" module (.top.sv)
# %.rtl.json:
# >     @echo "Building $(filter %.top.sv, $^)"
# ifeq ($(filter %.top.sv, $^),"")
# >     @echo No top module found, using auto-top
# >     yosys -p "read_verilog -sv $^ ; hierarchy -auto-top; proc; opt; fsm -expand; memory -nomap; wreduce -memx; opt_clean;" -o $@
# else
# >     @echo Top: $(filter %.top.sv, $^)
# >     @echo Module: $(subst .top.sv, , $(filter %.top.sv, $^))
# >     yosys -p "read_verilog -sv $^ ; hierarchy -auto-top; proc; opt; fsm -expand; memory -nomap; wreduce -memx; opt_clean;" -o $@
# >   yosys -p "read_verilog -sv $^ ; hierarchy -top $(subst .top.sv, , $(filter %.top.sv, $^)) ; proc; opt; fsm -expand; memory -nomap; wreduce -memx; opt_clean;" -o $@
# endif


%.ice40.svg:
>  yosys -p "read_verilog -sv $^ ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); synth_ice40; show -format svg -prefix $(basename $@)"

%.ice40.dot:
>  yosys -p "read_verilog -sv $^ ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); synth_ice40; show -prefix $(basename $@)"


%.aig.svg:
>  yosys -p "read_verilog -sv $^ ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); proc; opt; fsm ; opt; memory; aigmap; show -format svg -prefix $(basename $@) top"

%.ice40.rtl.json:
>  yosys -p "read_verilog -sv $^ ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); proc; opt_clean; fsm -expand; memory -nomap; wreduce -memx; opt_clean; synth_ice40; " -o $@

%.vcd: FORCE
>    rm -f $(@:.vcd=.sim)
>    iverilog -g 2012 \
>      -D TB_USE_SPI_FLASH_ROM=$(SIM_USE_SPI_FLASH_ROM) \
>      -I . \
>      -I NAND2TETRIS/05 \
>      -I VGA \
>      -I rom \
>      -I keyboard \
>      $(filter %.sv, $^) -o $(@:.vcd=.sim)
>    (cd $(dir $@) && vvp $(notdir $(@:.vcd=.sim)) )


# Rebuilding assembly-language based firmware images
CROSS=riscv64-unknown-elf-
CFLAGS=
FIRMWARE_PATH=$(MAKEFILE_PATH)../common/firmware
ASM_FW_BASE=$(FIRMWARE_PATH)/start.S $(FIRMWARE_PATH)/firmware.c
FIRMWARE_LDS=$(FIRMWARE_PATH)/upduino3_sections.lds
FIRMWARE_JSON=$(FIRMWARE_PATH)/firmware.json


%.fw.bin: FORCE
>	$(CROSS)gcc $(CFLAGS) -DICEBREAKER -mabi=ilp32 -march=rv32imc -Wl,-Bstatic,-T,$(FIRMWARE_LDS),--strip-debug,-N -ffreestanding -nostdlib -o $(subst .bin,.elf,$@) $(ASM_FW_BASE) $(filter %.s %.S %.c, $^)
>	$(CROSS)objcopy -O binary --set-section-flags .bootloader=alloc,load $(subst .bin,.elf,$@) $@


#../common/firmware/upduino3_sections.lds ../common/firmware/start.S ../common/firmware/firmware.c %.S


### BIN / Work in progress
# TODO: Decouple this into three steps
# # Check if there's a manta / debug JSON file.  If so, build it first (to manta.sv)
# Print an error if no PCF file
%.bin: FORCE
>     @echo "Building $(@:.bin=) using $(filter %.sv, $^)"
>     @if [ -z "$(filter %.pcf, $^)" ]; then echo "No PCF file found"; exit 1; fi
>     yosys -p "read_verilog -sv  $(filter %.sv, $^) ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); synth_ice40 $(YOSYS_ICE40_FLAGS) -json $(@:.bin=.json); tee -q -o $(@:.bin=.stats.json) stat -json;"
>     nextpnr-ice40 --threads $(NEXTPNR_THREADS) $(NEXTPNR_FLAGS) --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.bin=.json) --asc $(@:.bin=.asc)
>     icepack $(@:.bin=.asc) $@


$(ROM_SPI_IMAGE): $(ROM_HACK_IMAGE)
>     @echo "Packing Hack ROM $(ROM_HACK_IMAGE) -> $(ROM_SPI_IMAGE)"
>     printf '%s\n' \
>       'from pathlib import Path' \
>       'src = Path("$(ROM_HACK_IMAGE)")' \
>       'dst = Path("$(ROM_SPI_IMAGE)")' \
>       'dst.parent.mkdir(parents=True, exist_ok=True)' \
>       'data = bytearray()' \
>       'for line_no, raw in enumerate(src.read_text().splitlines(), start=1):' \
>       '    line = raw.strip()' \
>       '    if not line:' \
>       '        continue' \
>       '    if len(line) != 16 or any(ch not in "01" for ch in line):' \
>       '        raise SystemExit(f"{src}:{line_no}: invalid Hack word {raw!r}")' \
>       '    word = int(line, 2)' \
>       '    data.append((word >> 8) & 0xFF)' \
>       '    data.append(word & 0xFF)' \
>       'dst.write_bytes(data)' \
>       'print(f"Wrote {len(data)} bytes to {dst}")' | python3 -

products/rom.flash.bin: $(ROM_SPI_IMAGE) FORCE
>     @echo "Flashing ROM image $(ROM_SPI_IMAGE) at offset $(ROM_FLASH_OFFSET)"
>     @if ! command -v $(ICEPROG) >/dev/null 2>&1; then echo "ERROR: $(ICEPROG) not found in PATH"; exit 1; fi
>     @if [ ! -f "$(ROM_SPI_IMAGE)" ]; then echo "ERROR: ROM SPI image $(ROM_SPI_IMAGE) not found"; exit 1; fi
>     $(ICEPROG) -o $(ROM_FLASH_OFFSET) $(ROM_SPI_IMAGE)
>     @echo "Flash complete. Ensure SPI_FLASH_BASE_ADDR matches $(ROM_FLASH_OFFSET) in NAND2TETRIS/05/rom.sv"
>     @touch $@


%.placed.svg:
>     @echo "Building Placement SVG $@ using $(filter %.sv, $^)"
>     @if [ -z "$(filter %.pcf, $^)" ]; then echo "No PCF file found"; exit 1; fi
>     yosys -p "read_verilog -sv  $(filter %.sv, $^) ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); synth_ice40 $(YOSYS_ICE40_FLAGS) -json $(@:.placed.svg=.json); tee -q -o $(@:.placed.svg=.stats.json) stat -json;"
>     nextpnr-ice40 --threads $(NEXTPNR_THREADS) $(NEXTPNR_FLAGS) --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.placed.svg=.json) --placed-svg $@ --asc $(@:.placed.svg=.asc) --report $(@:.placed.svg=.report.json)

%.routed.svg:
>     @echo "Building Routed SVG $@ using $(filter %.sv, $^)"
>     @if [ -z "$(filter %.pcf, $^)" ]; then echo "No PCF file found"; exit 1; fi
>     yosys -p "read_verilog -sv  $(filter %.sv, $^) ; $(YOSYS_TOP_CHPARAM) $(YOSYS_HIERARCHY); synth_ice40 $(YOSYS_ICE40_FLAGS) -json $(@:.routed.svg=.json); tee -q -o $(@:.routed.svg=.stats.json) stat -json;"
>     nextpnr-ice40 --threads $(NEXTPNR_THREADS) $(NEXTPNR_FLAGS) --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.routed.svg=.json) --routed-svg $@ --asc $(@:.routed.svg=.asc) --report $(@:.routed.svg=.report.json)


# >     nextpnr-ice40 --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.bin=.json) --asc $(@:.bin=.asc)

# >     nextpnr-ice40 --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.bin=.json) --routed-svg $(@:.bin=.routed.svg) --placed-svg $(@:.bin=.placed.svg) --asc $(@:.bin=.asc)
# >     nextpnr-ice40 --up5k --package sg48 --pcf $(filter %.pcf, $^) --json $(@:.bin=.json) --write $(@:.bin=.nextpnr.json) --asc $(@:.bin=.asc)

# ifneq ($(filter %.debug.json, $^),"")
# # put the .sv in this directory and the resulting debug.json in the output directory
# >    cp $(filter %.debug.json, $^) $(@D)/$*.debug.json
# endif
# # include the manta .sv if one.  TODO

# need to translate AS and OBJDUMP errors to format: $(basename $1):0: ERROR:
# spinner.s:28: Error: illegal operands `mv ,s2,a2'
# Will remove any lines between lines that contain <RM> and </RM>
# >     sed '/<RM>/,/<\/RM>/d' $(filter %.s, $^)  $(filter %.S, $^) > $(@:.rom.txt=.temp.S)
# >     riscv64-unknown-elf-as -march=rv32i -mlittle-endian $(@:.rom.txt=.temp.S) -o $(@:.rom.txt=.o) 2>&1 |  sed -E 's/(^[^:]+:[0-9]+: )Error: /\1ERROR: /'
# >     riscv64-unknown-elf-objdump -d $(@:.rom.txt=.o) > $(@:.rom.txt=.dump)
# >     sed -n -E  -E "s/^[[:space:]]*[0-9a-fA-F]+:[[:space:]]*([0-9a-fA-F]{8})[[:space:]]+(.*)$$/\1 \/\/ \2/p" $(@:.rom.txt=.dump) > $@
# >     rm -f $(@:.rom.txt=.o) $(@:.rom.txt=.dump) $(@:.rom.txt=.temp)
# >     $(MAKEFILE_PATH)/SimpleRISC-VInstCheck.sh $@
%.rom.txt: FORCE
>     riscv64-unknown-elf-as  -march=rv32i -mabi=ilp32 -mlittle-endian $(filter %.s, $^)  $(filter %.S, $^) -o $(@:.rom.txt=.o) 2>&1 |  sed -E 's/(^[^:]+:[0-9]+: )Error: /\1ERROR: /'
>     riscv64-unknown-elf-ld -T $(MAKEFILE_PATH)/../common/cse2600.lds -m elf32lriscv $(@:.rom.txt=.o) -o $(@:.rom.txt=.exe)
>     riscv64-unknown-elf-objdump -d $(@:.rom.txt=.exe) > $(@:.rom.txt=.dump)
>     sed -n -E  -E "s/^[[:space:]]*[0-9a-fA-F]+:[[:space:]]*([0-9a-fA-F]{8})[[:space:]]+(.*)$$/\1 \/\/ \2/p" $(@:.rom.txt=.dump) > $@
>     rm -f $(@:.rom.txt=.o) $(@:.rom.txt=.dump) $(@:.rom.txt=.temp)
>     $(MAKEFILE_PATH)/SimpleRISC-VInstCheck.sh $@

$(ROM_SPI_IMAGE): $(ROM_HACK_IMAGE)
>     @echo "Packing Hack ROM $(ROM_HACK_IMAGE) -> $(ROM_SPI_IMAGE)"
>     python3 -c 'from pathlib import Path; src=Path("$(ROM_HACK_IMAGE)"); dst=Path("$(ROM_SPI_IMAGE)"); dst.parent.mkdir(parents=True, exist_ok=True); lines=[l.strip() for l in src.read_text().splitlines() if l.strip()]; bad=next(((idx,l) for idx,l in enumerate(lines,1) if len(l)!=16 or (set(l)-{"0","1"})), None); import sys; (sys.exit(f"{src}:{bad[0]}: invalid Hack word {bad[1]!r}") if bad else None); data=bytearray(); [data.extend(((w>>8)&255,w&255)) for w in (int(l,2) for l in lines)]; dst.write_bytes(data); print(f"Wrote {len(data)} bytes to {dst}")'

products/rom.flash.bin: $(ROM_SPI_IMAGE) FORCE
>     @echo "Flashing ROM image $(ROM_SPI_IMAGE) at offset $(ROM_FLASH_OFFSET)"
>     @if ! command -v $(ICEPROG) >/dev/null 2>&1; then echo "ERROR: $(ICEPROG) not found in PATH"; exit 1; fi
>     @if [ ! -f "$(ROM_SPI_IMAGE)" ]; then echo "ERROR: ROM SPI image $(ROM_SPI_IMAGE) not found"; exit 1; fi
>     $(ICEPROG) -o $(ROM_FLASH_OFFSET) $(ROM_SPI_IMAGE)
>     @echo "Flash complete. Ensure SPI_FLASH_BASE_ADDR matches $(ROM_FLASH_OFFSET) in NAND2TETRIS/05/rom.sv"
>     @touch $@

#>	$(CROSS)gcc $(CFLAGS) -DICEBREAKER -mabi=ilp32 -march=rv32imc -Wl,-Bstatic,-T,$(FIRMWARE_LDS),--strip-debug,-N -ffreestanding -nostdlib -o $(subst .bin,.elf,$@) $(ASM_FW_BASE) $(filter %.s %.S %.c, $^)


# >     rm -f $(@:.rom.txt=.o) $(@:.rom.txt=.dump) $(@:.rom.txt=.temp)


# >    @build=$(call check_build,$@,$^)
# >    if [ $$build -eq 1 ]; then
# >       echo "Building $@ using $^"
# >       pcf=$(filter %.pcf,$^);
# >       echo "PCF: $${pcf}"
# >       verilog=$(filter %.sv,$^);
# >       echo "Verilog: $${verilog}"
# >       manta=$(filter %.debug.json,$^);   ## TODO: Manta processing
# >       yosys -p "read_verilog -sv $${verilog} ; hierarchy -auto-top; proc; opt_clean; fsm -expand; memory -nomap; wreduce -memx; opt_clean; synth_ice40 -json $(PRODUCTS_DIR)/$*.json; tee -q -o $(PRODUCTS_DIR)/$*.stats.json stat;"
# >       nextpnr-ice40 --up5k --package sg48 --pcf $${pcf} --json $(PRODUCTS_DIR)/$*.json --asc $(PRODUCTS_DIR)/$*.asc
# >       icepack $(PRODUCTS_DIR)/$*.asc $(IMAGES_DIR)/$@
# >    else
# >       echo "$@ is up to date."
# >    fi;
# >    ## Open programmer



# %.bin: ${IMAGES_DIR}
# >    @build=$(call check_build,$@,$^)
# >    if [ $$build -eq 1 ]; then
# >       echo "Building $@ using $^"
# >       pcf=$(filter %.pcf,$^);
# >       echo "PCF: $${pcf}"
# >       verilog=$(filter %.sv,$^);
# >       echo "Verilog: $${verilog}"
# >       manta=$(filter %.debug.json,$^);   ## TODO: Manta processing
# >       yosys -p "read_verilog -sv $${verilog} ; hierarchy -auto-top; proc; opt_clean; fsm -expand; memory -nomap; wreduce -memx; opt_clean; synth_ice40 -json $(PRODUCTS_DIR)/$*.json; tee -q -o $(PRODUCTS_DIR)/$*.stats.json stat;"
# >       nextpnr-ice40 --up5k --package sg48 --pcf $${pcf} --json $(PRODUCTS_DIR)/$*.json --asc $(PRODUCTS_DIR)/$*.asc
# >       icepack $(PRODUCTS_DIR)/$*.asc $(IMAGES_DIR)/$@
# >    else
# >       echo "$@ is up to date."
# >    fi;
# >    ## Open programmer


# $(PRODUCTS_DIR):
# >	mkdir -p $(PRODUCTS_DIR)

# $(IMAGES_DIR):
# >	mkdir -p $(IMAGES_DIR)

# .PHONY: clean
# clean:
# >	 rm -f $(PRODUCTS_DIR)/*.rtl.json
# >	 rm -f $(PRODUCTS_DIR)/*.vcd
# >	 rm -f $(PRODUCTS_DIR)/*.bin
# >	 rm -f $(PRODUCTS_DIR)/*.json
# >	 rm -f $(PRODUCTS_DIR)/*.asc
