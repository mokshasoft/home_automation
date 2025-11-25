SRC = $(shell find src -name '*.hs')

format:
	fourmolu -i $(SRC)

lint:
	hlint $(SRC)
