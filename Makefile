all: dos2unix black isort pylint

black:
	@echo "Code formatting"
	poetry run black bin/*.py

isort:
	@echo "Imports sorting"
	poetry run isort bin/*.py

pylint:
	@echo "Code QC"
	poetry run pylint bin/*.py

dos2unix:
	@echo "Reformatting"
	dos2unix bin/*.py