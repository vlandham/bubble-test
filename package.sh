#!/usr/bin/env bash

NAME="gsa_inventory"

rm -rf $NAME
rm -rf $NAME.zip
mkdir -p $NAME
cp -r js img data css index.html $NAME/
rm $NAME/**/.DS_Store
zip -r $NAME $NAME/*
rm -rf $NAME

