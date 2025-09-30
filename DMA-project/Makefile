R=Rscript

.PHONY: install run test clean

install:
	$(R) R/install_packages.R

run: install
	$(R) scripts/run_all.R

test:
	$(R) -e "testthat::test_dir('tests')"

clean:
	$(R) R/clean_outputs.R