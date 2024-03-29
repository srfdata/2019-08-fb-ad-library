#!/bin/bash
# knit
source knit.sh
# special case: 
git add analysis/output/ads.csv
git commit -m "daily production of ads.csv"
git push origin master
# make temporary copy of preprocessing folder with all data we need in build
cp -r analysis tmp
mv deploy.sh tmp/
# special case
mv run.sh tmp/
# switch to gh-pages branch
git checkout gh-pages
if [ $? -eq 0 ]
then
  echo "changed to gh-pages"
else
  # revert
  mv tmp/deploy.sh deploy.sh
  rm -rf tmp/
  exit 1
fi
# copy over index file (the processed main.Rmd) from master branch
cp tmp/main.html index.html
# clean
rm -rf rscript/
mkdir rscript
# copy over necessary scripts from master branch 
cp tmp/main.Rmd rscript
# cp index.html rscript
# copy over other nessecary output files from master branch
cp -r tmp/output rscript/
# copy over other necessary input files from master branch
cp -r tmp/input rscript/
cp -r tmp/scripts rscript/
# remove ignore folder from folder that gets zipped
rm -rf rscript/output/ignore
rm -rf rscript/input/ignore
# zip the rscript folder
zip -r rscript.zip rscript
# remove the rscript folder
rm -rf rscript
# remove analysis folder
rm -rf analysis
# add everything for committing
git add .
git add -u
# commit in gh-pages
git commit -m "analysis: build and deploy to gh-pages"
# push to remote:gh-pages
git push origin gh-pages 
# checkout master again
git checkout master
# copy back deploy.sh
mv tmp/deploy.sh .
# special case
mv tmp/run.sh .
mv tmp/.env analysis/.
# create folders if they don't exist anymore
mkdir analysis/input
mkdir analysis/output
# copy back output/ignore
mv tmp/output/ignore analysis/output/
# copy back input/ignore
mv tmp/input/ignore analysis/input/
# remove temporary folder
rm -rf tmp
