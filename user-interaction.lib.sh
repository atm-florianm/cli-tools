#!/usr/bin/env bash

<<'EC'
Fonctions-outils pour l'interaction avec l'utilisateur.

color_print()    → affiche un texte en couleur
                   color_print red "Erreur"

frame_print()    → affiche un texte dans un encadré
                   frame_print "À lire avant toute chose"

get_one_letter() → retourne un caractère tapé par l'utilisateur (sans attendre la touche Entrée)
                   letter=$(get_one_letter "Your choice?")

get_yes_no()     → retourne une réponse tapée par l'utilisateur parmi deux autorisées
                   reply=$(get_yes_no o n "Voulez-vous continuer (o/n) ?")

rep()            → répète un caractère

EC


# works from bash 4.0; even old debians have bash 4 but Mac OS X doesn't
declare -A COLORS
COLORS[grey]=30
COLORS[red]=31
COLORS[green]=32
COLORS[yellow]=33
COLORS[blue]=34
COLORS[purple]=35
COLORS[cyan]=36
COLORS[white]=37
COLORS[hi_grey]=40
COLORS[hi_red]=41
COLORS[hi_green]=42
COLORS[hi_yellow]=43
COLORS[hi_blue]=44
COLORS[hi_purple]=45
COLORS[hi_cyan]=46
COLORS[hi_white]=47

# Exemple:
# color_print red "Attention, ceci est important"
color_print() {
    if [[ -z "${COLORS[$1]}" ]]; then
        color_code="$1"
    else
        color_code=${COLORS[$1]}
    fi
    printf "\x1b[""$color_code""m$2\x1b[0m\n"
}

# répète un caractère n fois:
# Exemple:
# rep 10 "="
# retournera '=========='
rep() {
    n=$1
    c=$2
    # https://stackoverflow.com/questions/5349718/how-can-i-repeat-a-character-in-bash
    printf "%.0s$c" $(seq 0 $(( n - 1)) )
}

# Affiche un message dans un encadré.
# Attention aux caractères accentués : selon la locale, il est possible que
# la longueur de la chaîne soit calculée en octets et pas en caractères.
# Exemple:
# frame_print "Ceci est un message à caractère informatif"
# Résultat:
#         ┌────────────────────────────────────────────┐
#         │ Ceci est un message à caractère informatif │
#         └────────────────────────────────────────────┘
#                 
frame_print() {
    width=$(($(tput cols) - 1))
    text="$1"
    len=${#text}
    frametop='┌'$(rep $(( len + 2 )) '─')'┐'
    framemiddle='│ '$text' │'
    framebottom='└'$(rep $(( len + 2 )) '─')'┘'

    #uneven=$(( (width - len) % 2 ))
    pad=$(( (width - len) / 2 ))
    #padleft=$(rep $pad " ")
    #padright=$(rep $(( pad + uneven )) " ")
    padleft=$(rep $(( pad - 2 )) " ")
    printf "$padleft $frametop\n$padleft $framemiddle\n$padleft $framebottom\n"
}

# Lit une seule lettre depuis stdin (l'utilisateur n'a pas besoin d'appuyer sur Entrée)
# ⚠ utiliser avec parcimonie : pour les questions importantes, mieux vaut que l'utilisateur
# soit obligé d'appuyer sur Entrée; Attention aussi aux choix numériques : à partir de 10
# choix, l'utilisateur ne peut plus choisir !
get_one_letter() {
    read -n 1 -p "$1 " l
    echo "" >&2
    echo "$l"
}

# Permet d'obtenir un input de l'utilisateur parmi deux choix possibles;
# tant que l'input ne sera pas parmi ces choix, l'utilisateur devra taper
# de nouveau sa réponse.
# Exemple:
# reponse=$(get_yes_no 'o' 'n' 'Confirmez-vous cette action (o/n) ?')
# if [[ $response == 'n' ]]; then echo 'abandon'; else echo 'on continue'; fi
get_yes_no() {
    response_y="$1"
    response_n="$2"

    # default values if arguments not provided
    test -z "$response_y" && response_y="y"
    test -z "$response_n" && response_n="n"

    read -p "$3 " yesno
    yesno="${yesno,,}" # convert to lowercase

    while [[ "$yesno" != "$response_y" && "$yesno" != "$response_n" ]]; do
        read -p "$3 " yesno
        yesno="${yesno,,}" # convert to lowercase
    done
    echo $yesno
}

# Même chose que get_yes_no, sauf que l'utilisateur n'a pas à appuyer sur Entrée.
# Attention: $1 et $2 doivent avoir une longueur de 1 caractère.
get_yes_no_noncritical() {
    response_y="$1"
    response_n="$2"

    # default values if arguments not provided
    test -z "$response_y" && response_y="y"
    test -z "$response_n" && response_n="n"

    yesno=$(get_one_letter "$3")
    yesno="${yesno,,}" # convert to lowercase

    while [[ "$yesno" != "$response_y" && "$yesno" != "$response_n" ]]; do
        yesno=$(get_one_letter "$3")
        yesno="${yesno,,}" # convert to lowercase
    done
    echo $yesno

}
