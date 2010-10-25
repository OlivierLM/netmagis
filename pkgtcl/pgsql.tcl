#
# $Id$
#
# Librairie de fonctions TCL pour faciliter l'acc�s � une base PostgreSQL
#
# Historique
#   1999/04/16 : pda      : conception
#   1999/04/17 : pda      : separation en une librairie
#   2002/05/03 : pda/jean : ajout de getcols
#   2003/05/30 : pda/jean : ajout de lock/unlock
#   2003/06/13 : pda/jean : autorisation de requ�tes vides dans pg_exec
#

package provide pgsql 1.2
package require Pgtcl

namespace eval pgsql {
    namespace export quote execsql getcols lock unlock
}

##############################################################################
# Acc�s � une base PostgreSQL
##############################################################################

#
# Neutralise les caract�res sp�ciaux figurant dans une cha�ne,
# de fa�on � pouvoir la passer au moteur SQL.
# - double toutes les apostrophes
#
# Entr�e :
#   - param�tres
#	- chaine : cha�ne � traiter
#	- maxindex (optionnel) : taille maximum de la cha�ne
# Sortie :
#   - valeur de retour : la cha�ne trait�e
#
# Historique
#   1999/07/14 : pda : conception et codage
#   1999/10/24 : pda : mise en package
#

proc ::pgsql::quote {chaine {maxindex 99999}} {
    set chaine [string range $chaine 0 $maxindex]
    regsub -all {'} $chaine {&&} chaine
    regsub -all {\\} $chaine {&&} chaine
    return $chaine
}

#
# Ex�cute une commande sql, et affiche une erreur et sort
# en cas de probl�me. Retourne le r�sultat de la commande
# (r�sultat pour pg_result).
#
# Entr�e :
#   - param�tres
#	- dbfd : la base
#	- cmd : la commande � passer
#	- result : contient en retour le nom de la variable contenant l'erreur
# Sortie :
#   - valeur de retour : 1 si tout est ok, 0 sinon
#   - variable result :
#	- si erreur, la variable contient le message d'erreur
#
# Historique
#   1999/07/14 : pda      : conception et codage
#   1999/10/24 : pda      : mise en package
#   2003/06/13 : pda/jean : autorisation des requ�tes vides
#

proc ::pgsql::execsql {dbfd cmd result} {
    upvar $result rmsg

    set res [pg_exec $dbfd $cmd]
    switch -- [pg_result $res -status] {
	PGRES_COMMAND_OK -
	PGRES_TUPLES_OK -
	PGRES_EMPTY_QUERY {
	    set ok 1
	    set rmsg {}
	}
	default {
	    set ok 0
	    set rmsg "$cmd : [pg_result $res -error]"
	}
    }
    pg_result $res -clear
    return $ok
}

#
# R�cup�re une liste de colonnes d'une table
#
# Entr�e :
#   - param�tres
#	- dbfd : la base
#	- table : la commande � passer
#	- where : clause where �ventuelle (sans le WHERE)
#	- order : clause order �ventuelle (sans le ORDER BY)
#	- lcol : liste des colonnes � r�cup�rer
# Sortie :
#   - valeur de retour : liste
#
# Historique
#   2002/05/03 : pda/jean : conception et codage
#

proc ::pgsql::getcols {dbfd table where order lcol} {
    if {! [string equal $where ""]} then {
	set where "WHERE $where"
    }
    if {! [string equal $order ""]} then {
	set order "ORDER BY $order"
    }
    set selcol [join $lcol ", "]
    set lres {}
    pg_select $dbfd "SELECT $selcol FROM $table $where $order" tab {
	set l {}
	foreach c $lcol {
	    lappend l $tab($c)
	}
	lappend lres $l
    }
    return $lres
}

#
# Entame une transaction et verrouille une ou plusieurs tables
#
# Entr�e :
#   - param�tres
#	- dbfd : la base
#	- ltab : liste des tables � verrouiller
#	- result : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si tout est ok, 0 sinon
#   - variable result :
#	- si erreur, la variable contient le message d'erreur
#
# Historique
#   2002/05/03 : pda/jean : conception et codage
#

proc ::pgsql::lock {dbfd ltab result} {
    upvar $result msg

    set sql "BEGIN WORK ;"
    foreach t $ltab {
	append sql " LOCK $t ;"
    }

    if {[::pgsql::execsql $dbfd $sql msg]} then {
	set r 1
	set msg ""
    } else {
	set r 0
	set msg "Transaction impossible : $msg"
    }

    return $r
}

#
# Termine une transaction, et d�verrouille les tables.
# Eventuellement, interrompt la transaction sans faire le "commit"
#
# Entr�e :
#   - param�tres
#	- dbfd : la base
#	- commit : "commit" ou "abort"
#	- result : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si tout est ok, 0 sinon
#   - variable result :
#	- si erreur, la variable contient le message d'erreur
#
# Historique
#   2002/05/03 : pda/jean : conception et codage
#

proc ::pgsql::unlock {dbfd commit result} {
    upvar $result msg

    switch -- $commit {
	"commit" {
	    set sql "COMMIT WORK"
	}
	"abort" {
	    set sql "ABORT WORK"
	}
	default {
	    set msg "Param�tre 'commit' incorrect ('$commit')"
	    return 0
	}
    }

    if {[::pgsql::execsql $dbfd $sql msg]} then {
	set r 1
	set msg ""
    } else {
	::pgsql::execsql $dbfd "ABORT WORK" m
	set r 0
	set msg "Echec de la transaction : $msg"
    }

    return $r
}
