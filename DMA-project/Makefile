R=Rscript

.PHONY: install run test clean

install:
	$(R) R/install_packages.R

run: install
	$(R) scripts/run_all.R

test:
	$(R) -e "testthat::test_dir('tests')"

clean:
	rm -f artifacts/*.rds artifacts/*.csv artifacts/*.txt
	rm -f reports/*.png