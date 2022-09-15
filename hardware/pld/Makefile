CUPL=C:\Wincupl\Shared\cupl.exe
CUPL_FLAGS=-j g16v8a

all: cpu horizontal vertical dma

cpu:
	$(CUPL) $(CUPL_FLAGS) cpu.pld

horizontal:
	$(CUPL) $(CUPL_FLAGS) horizontal.pld
vertical:
	$(CUPL) $(CUPL_FLAGS) vertical.pld
dma:
	$(CUPL) $(CUPL_FLAGS) dma.pld

clean:
	del *.jed *.abs *.si *.slm *.so *.wo *.sim
