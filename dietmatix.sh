#!/bin/bash
#
# script assumes that https://github.com/globalbioticinteractions/elton , https://github.com/globalbioticinteractions/nomer
# and apache spark are available via elton, nomer, and spark-shell aliases respectively.
#

elton interactions | cut -f1,2,8,9,10 | sort | uniq | gzip > interactions.tsv.gz
zcat interactions.tsv.gz | cut -f3 | sort | uniq > interactionLabel.tsv
zcat interactions.tsv.gz | grep -P "(\teatenBy\t|\tpreyedUponBy\t)" | awk -F '\t' '{ print $4 "\t" $5 "\t" $1 "\t" $2 }' | gzip > interactionsPredPrey.tsv.gz 
zcat interactions.tsv.gz | grep -P "(\teats\t|\tpreysOn\t)" | cut -f1,2,4,5 | gzip >> interactionsPredPrey.tsv.gz
zcat interactionsPredPrey.tsv.gz | nomer append | grep SAME_AS | cut -f3,4,6,7 | gzip > interactionsPreyPred.tsv.gz

# map to prey orders
nomer properties | grep -v "nomer.append.schema.output" > my.properties
echo 'nomer.append.schema.output=[{"column":0, "type":"id"}, {"column":1, "type":"name"}, {"column": 2, "type": "rank"}, {"column":3,"type":"path.order.id"},{"column":4,"type":"path.order.name"},{"column":5,"type":"path.order"}]' >> my.properties
zcat interactionsPreyPred.tsv.gz | grep -P ".*\t.*\tFBC:FB" | nomer append --properties=my.properties | grep SAME_AS | gzip > fbPreyPredSameAsWithOrder.tsv.gz

# remove likely homonyms
zcat fbPreyPredSameAsWithOrder.tsv.gz | awk -F '\t' '{ print $1 "\t" $2 "\t" $6 "\t" $7 }' | sort | uniq | gzip > fbPreyMap.tsv.gz

cat removeLikelyHomonyms.scala | spark-shell
cat fbPreyLikelyHomonyms/*.csv | sort | uniq > fbPreyLikelyHomonyms.tsv
cat fbPredPreySameAsWithOrderNoHomonyms/*.csv | grep -v -P "\t\t$" | sort | uniq | gzip > fbPredPreySameAsWithOrderNoHomonyms.tsv.gz

zcat fbPredPreySameAsWithOrderNoHomonyms.tsv.gz | awk -F '\t' '{ print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 }' | sort | uniq | gzip > fbPredPreyOrderUnmapped.tsv.gz

zcat fbPredPreyOrderUnmapped.tsv.gz | sed -f mapOrders.sed | sort | uniq | gzip > fbPredPreyOrder.tsv.gz
zcat fbPredPreyOrder.tsv.gz | cut -f4,6 | sort | uniq -c | sort -n -r > fbPredPreyOrderPreyFrequency.tsv

# calc majority orders

cat calcMajorityOrders.scala | spark-shell
cat majorityOrders/*.csv > majorityOrders.tsv
cat minorityOrders/*.csv > minorityOrders.tsv
cat fbPredPreyMajorityOrder/*.csv | sort | uniq > fbPredPreyMajorityOrder.tsv
cat fbPredPreyMajorityOrderCount/*.csv | sort | uniq > fbPredPreyMajorityOrder.tsv

