.PHONY: default setup load merge-reviews build dq top50 dashboard check-docs all reset
default: all   # `make` runs the whole pipeline (put the CSVs in data/raw/ first)
setup:
	uv sync
load:
	uv run whitecircle load
merge-reviews:   # skipped when data/verify/ is absent: the committed seed already holds the labels
	@if ls data/verify/review_part*.csv >/dev/null 2>&1; then uv run whitecircle merge-reviews; else echo 'no data/verify/review_part*.csv: using committed seed'; fi
build:
	uv run whitecircle build
dq:
	uv run whitecircle dq
top50:
	uv run whitecircle top50
dashboard:
	uv run whitecircle dashboard
check-docs:   # fails if the memo figures drift from the warehouse
	uv run whitecircle check-docs
all: load merge-reviews build dq top50 dashboard check-docs
reset:   # deletes only the warehouse file; raw CSVs are untouched
	rm -f data/white_circle.duckdb
