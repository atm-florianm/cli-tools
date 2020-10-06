#!/usr/bin/env bash

<<'EC'
Fonctions-outils pour la maintenance d’instances dolibarr en bash.

get_dolibarr_root() → cherche la racine dolibarr depuis n'importe quel sous-répertoire

val_from_conf() → extrait une variable du conf.php

list_direct_subdirs()

EC


# Fonction pour repérer si on est dans une instance Dolibarr.
# Pour ça, on cherche un conf.php.
get_dolibarr_root() {
    initial_dir="$(pwd)"

    # on remonte dans l'arborescence jusqu'à ce qu'on trouve ce qui ressemble à une
    # racine dolibarr.
    while [[ "$(pwd)" != "/" ]]; do
        if [[ -e "./htdocs/conf/conf.php" ]]; then
            echo "$(pwd)"
            cd "$initial_dir"
            break
        fi
        cd ..
    done
}

# Fonction pour avoir la liste des sous-répertoires directs du répertoire courant
# (ou, si applicable, du répertoire passé en paramètre)
# Attention : inclut aussi les répertoires cachés
list_direct_subdirs() {
    if [[ "$1" != "" ]]; then
        d="$1"
    else
        d="$(pwd)"
    fi
    find "$d" -mindepth 1 -maxdepth 1 -type d
}

# Fonction pour récupérer une valeur brute du conf.php Dolibarr.
# Ne fonctionne pas si les affectations faites dans le conf.php
# sont plus complexes que $ma_variable = "ma_valeur" (ça nécessiterait
# d'appeler un interpréteur php).
# Cas non couverts :
#    - valeurs contenant "'" ou '"' (ex: $dolibarr_main_db_name = "im'possi\"ble_dolibarr";)
#    - commentaire multiligne = possible faux positif
#    - variable dont la valeur est une expression (ex: $dolibarr_main_db_name = $truc . '_dolibarr';)
#    - variable dont l'affectation est à la suite d'une autre instruction sur la ligne
# Pour tous ces cas (qui n'existent pas sur nos serveurs mais, qui sait ?), il faudrait appeler
# php.
#
# Exemple: val_from_conf "dolibarr_main_db_name"
#
# @param $1 Nom (complet) de la variable de conf à extraire
val_from_conf() {
    dol_root="$(get_dolibarr_root)"
    if [[ "$dol_root" == "" ]]; then return; fi
    dol_conf_file="$dol_root/htdocs/conf/conf.php"

    # solution 1 (nécessite un fichier conf.php standardisé)
    #grep "^\s*\$$1" "$dol_conf_file" | sed "s/^.$1\s*=\s*\([\"']\)\([^'\"]*\)\\1.*/\\2/g"

    # solution 2 (fonctionne avec n'importe quel conf.php, mais présente un risque
    #             si jamais conf.php fait plus que juste affecter des variables)
    script="<?php include '$dol_conf_file'; echo \$$1 . \"\n\";"
    #echo "$script"
    echo "$script" | php
}



# TODO
# Vérifie si l'installation de Dolibarr est OK et donne des diagnostics
# ex : ça pourrait vérifier que le conf.php correspond bien au serveur
# sur lequel on se trouve, que la bdd est montée, que le répertoire documents
# a les bons droits, etc.
check_dolibarr_ok() {
    dol_root="$(get_dolibarr_root)"
    if [[ "$dol_root" == "" ]]; then return; fi

    docfolder=$(val_from_conf dolibarr_main_data_root)
    # check documents
    
}
