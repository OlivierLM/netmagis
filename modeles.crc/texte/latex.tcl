#
# $Id: latex.tcl,v 1.2 2007-03-13 21:08:01 pda Exp $
#
# Mod�le "texte"
#
# Historique
#   1999/06/21 : pda : conception d'un mod�le latex pour validation multimod�le
#   1999/07/02 : pda : simplification
#

#
# Inclure les directives de formattage de base
#

inclure-tcl include/latex/base.tcl

###############################################################################
# Proc�dures de conversion LaTeX sp�cifiques au mod�le
###############################################################################

proc htg_partie {} {
    global partie

    if [catch {set id [htg getnext]} v] then {error $v}
    if [catch {set texte [htg getnext]} v] then {error $v}
    set texte [nettoyer-latex $texte]

    switch -exact $id {
	banniere	-
	titrepage	{ set texte {} }
    }

    set partie($id) $texte  
    return {}
}

###############################################################################
# Proc�dures du bandeau, communes � tous les mod�les
###############################################################################

inclure-tcl include/latex/bandeau.tcl
