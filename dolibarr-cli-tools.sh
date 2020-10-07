#!/usr/bin/env bash

<<'EC'
Fonctions-outils pour la maintenance d’instances dolibarr en bash.

get_dolibarr_root() → cherche la racine dolibarr depuis n'importe quel sous-répertoire
get_val_from_conf() → extrait une variable du conf.php
get_direct_subdirs()
get_apache_user() → donne l'utilisateur apache (la plupart du temps www-data)
EC

source "user-interaction.lib.sh"

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
get_direct_subdirs() {
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
# @param $2 Valeur par défaut si non trouvé
get_val_from_conf() {
    dol_root="$(get_dolibarr_root)"
    if [[ "$dol_root" == "" ]]; then return; fi
    dol_conf_file="$dol_root/htdocs/conf/conf.php"

    # solution 1 (nécessite un fichier conf.php standardisé)
    #grep "^\s*\$$1" "$dol_conf_file" | sed "s/^.$1\s*=\s*\([\"']\)\([^'\"]*\)\\1.*/\\2/g"

    # solution 2 (fonctionne avec n'importe quel conf.php, mais présente un risque
    #             si jamais conf.php fait plus que juste affecter des variables)
    script="<?php include '$dol_conf_file'; if(isset(\$$1)) echo \$$1; else echo \"$2\";"
    #echo "$script"
    echo "$script" | php
}

# Retourne l'utilisateur apache (généralement www-data)
get_apache_user() {
    # afficher les infos des processus apache2 et httpd (les noms potentiels d’apache)
    # sed pour filtrer la première colonne
    # egrep -v pour supprimer UID et root
    # head -1 pour ne garder qu'une ligne
    ps -f -C "apache2,httpd" \
        | sed 's/^\(\S\+\).*/\1/g' \
        | egrep -v "(UID|root)" \
        | head -1
}


# TODO
# Vérifie si l'installation de Dolibarr est OK et donne des diagnostics
# ex : ça pourrait vérifier que le conf.php correspond bien au serveur
# sur lequel on se trouve, que la bdd est montée, que le répertoire documents
# a les bons droits, etc.
check_dolibarr_ok() {
    dol_root="$(get_dolibarr_root)"
    if [[ "$dol_root" == "" ]]; then return; fi

    docfolder=$(get_val_from_conf dolibarr_main_data_root)
    # check documents

    
}


# Options:
#  - nomail = désactivera globalement l'envoi d'e-mails
#  - color = changera la couleur de fond (pour indiquer
#            qu'on n'est pas sur la prod)
# Le nom de la base sera celui défini par le conf.php
mount_dolibarr_database() {

    # TODO: check if db exists; if not, add command to create it

    dbname="$(get_val_from_conf dolibarr_main_db_name)"
    dbuser="$(get_val_from_conf dolibarr_main_db_user)"
    mysqlcom="mysql -u\"$dbuser\""\
        " -p\"\$(get_val_from_conf dolibarr_main_db_pass)\""\
        " \"$dbname\""


}

mount_database_interactive() {
    wd="$(pwd)"
    documentsdir="$(get_val_from_conf dolibarr_main_data_root)"

    r=$(get_yes_no_noncritical o n "Faut-il chercher les dumps dans 'admin/backup' du dossier documents? (o = oui; n = chercher dans le répertoire courant)")
    if [[ "$r" == 'o' ]]; then
        dumpdir="$documentsdir/admin/backup"
        cd "$dumpdir"
    else
        dumpdir='.'
    fi
    declare -A TDump
    TDump[none]='none'
    # TODO vérifier automatiquement si xzcat, bzcat, gzcat, unzip sont installés
    dumps=`ls *.bz2 *.gz *.xz *.sql.zip *.sql 2>/dev/null`
    cd "$wd" # retour au répertoire d'origine
    let i=0
    for dump in $dumps; do
        let i++
        TDump[$i]="$dumpdir/$dump"
        printf "% 2d) %s\n" "$i" "$dump"
    done
    read -p "Choix? " choice
    while [[ -z "${TDump[$choice]}" ]]; do
        read -p "Choix? " choice
    done
    choosen_dump="${TDump[$choice]}"
    re_file_ext='.*\.\(bz2\|gz\|zip\|xz\|sql\)$'
    file_ext=`expr "$choosen_dump" : "$re_file_ext"`
    dbname="$(get_val_from_conf dolibarr_main_db_name)"
    dbuser="$(get_val_from_conf dolibarr_main_db_user)"
    base_mysqlcom="mysql -u\"$dbuser\"\
         -p\"\$dbpass\"\
         \"$dbname\""

    case "$file_ext" in
        gz )
            mysqlcom=$(printf "gunzip --stdout %s | %s" "$choosen_dump" "$base_mysqlcom");;
        bz2 )
            mysqlcom=$(printf "bzcat %s | %s" "$choosen_dump" "$base_mysqlcom");;
        xz )
            mysqlcom=$(printf "xzcat %s | %s" "$choosen_dump" "$base_mysqlcom");;
        zip )
            mysqlcom=$(printf "unzip -c %s | %s" "$choosen_dump" "$base_mysqlcom");;
        sql )
            mysqlcom=$(printf "%s < %s" "$base_mysqlcom" "$choosen_dump");;
    esac

    db_prefix="$(get_val_from_conf dolibarr_main_db_prefix)"

    # TODO en fonction des options, donner ces commandes supplémentaires
    sqlcomm_disable_email="UPDATE $db_prefix""const SET value = 1 WHERE name = \"MAIN_DISABLE_ALL_MAILS\";";
    sqlcomm_set_admin_pwd="UPDATE $db_prefix""user SET pass = \"admin\" WHERE rowid > 0;"
    sqlcomm_set_bgcolor="UPDATE $db_prefix""const SET value = \"c63ed6\" WHERE name = \"THEME_ELDY_BACKBODY\";"


    color_print red "dbpass=\"\$""(get_val_from_conf dolibarr_main_db_pass)\""
    color_print red "$mysqlcom"

    r=$(get_yes_no_noncritical o n "Désactiver tous les e-mails? (o/n)")
    [[ $r == 'o' ]] && color_print red "$base_mysqlcom -e '$sqlcomm_disable_email'"

    r=$(get_yes_no_noncritical o n "Remplacer tous les mots de passe par 'admin'? (o/n)")
    [[ $r == 'o' ]] && color_print red "$base_mysqlcom -e '$sqlcomm_set_admin_pwd'"

    r=$(get_yes_no_noncritical o n "Passer la couleur de fond du bandeau en magenta moche? (o/n)")
    [[ $r == 'o' ]] && color_print red "$base_mysqlcom -e '$sqlcomm_set_bgcolor'"
}

mount_database_for_prod() {
    #
    echo ""
}
