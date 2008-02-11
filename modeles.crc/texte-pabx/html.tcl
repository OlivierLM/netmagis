#
# $Id: html.tcl,v 1.2 2008-02-11 14:45:30 pda Exp $
#
# Mod�le "texte"
#
# Historique
#   1998/06/15 : pda : conception
#   1999/06/20 : pda : s�paration du langage HTML
#   1999/07/02 : pda : simplification
#   1999/07/25 : pda : int�gration des tableaux de droopy
#

#
# Inclure les directives de formattage de base
#

inclure-tcl include/html/base.tcl

###############################################################################
# Proc�dures de conversion HTML sp�cifiques au mod�le
###############################################################################

proc htg_titre {} {
    if [catch {set niveau [htg getnext]} v] then {error $v}
    check-int $niveau
    if [catch {set texte  [htg getnext]} v] then {error $v}
    switch $niveau {
	1	{
            set texte  "<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\"><tr><td align=\"center\" valign=\"top\" class=\"print_image\"><img src=\"/images/logo_osiris_print.jpeg\" alt=\"\"></td><td align=\"center\" valign=\"middle\"><H2>$texte</H2></td></tr></table>"
	}
	2	{
	    set texte "<H3>$texte</H3>"
	}
	default	{
	    incr niveau
	    set texte "<H$niveau>$texte</H$niveau>"
	}
    }
    return $texte
}

proc htg_partie {} {
    global partie

    if [catch {set id [htg getnext]} v] then {error $v}
    if [catch {set texte [htg getnext]} v] then {error $v}
    set texte [nettoyer-html $texte]

    switch -exact $id {
	banniere	-
	titrepage	{
	    regsub -all "\n" $texte "<BR>\n" texte
	}
	default {
	    regsub -all "\n\n+" $texte "<P>" texte
	}
    }

    set partie($id) $texte
    return {}
}

###############################################################################
# Proc�dures du bandeau, communes � tous les mod�les
###############################################################################

inclure-tcl include/html/bandeau.tcl
