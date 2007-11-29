#
# Librairie TCL pour l'application de gestion de l'authentification.
#
# Historique
#   2003/05/30 : pda/jean : conception
#   2003/12/11 : pda      : simplification
#

##############################################################################
# Acc�s � la base
##############################################################################

#
# Initialiser l'application Web auth
#
# Entr�e :
#   - param�tres :
#	- nologin : nom du fichier test� pour le mode "maintenance"
#	- auth : param�tres d'authentification
#	- pagerr : fichier HTML contenant une page d'erreur
#	- form : les param�tres du formulaire
#	- ftabvar : tableau contenant en retour les champs du formulaire
#	- loginvar : login de l'utilisateur, en retour
# Sortie :
#   - valeur de retour : aucune
#   - param�tres :
#	- ftabvar : cf ci-dessus
#	- loginvar : cf ci-dessus
#
# Historique
#   2001/06/18 : pda      : conception
#   2002/12/26 : pda      : actualisation et mise en service
#   2003/05/13 : pda/jean : int�gration dans dns et utilisation de auth
#   2003/05/30 : pda/jean : r�utilisation pour l'application auth
#   2003/06/04 : pda/jean : simplification
#

proc init-auth {nologin auth pagerr form ftabvar loginvar} {
    upvar $ftabvar ftab
    upvar $loginvar login

    #
    # Pour le cas o� on est en mode maintenance
    #

    ::webapp::nologin $nologin %ROOT% $pagerr

    #
    # Acc�s � la base d'authentification
    #

    set msg [::auth::init $auth]
    if {! [string equal $msg ""]} then {
	::webapp::error-exit $pagerr $msg
    }

    #
    # Le login de l'utilisateur (la page est prot�g�e par mot de passe)
    #

    set login [::webapp::user]
    if {[string compare $login ""] == 0} then {
	::webapp::error-exit $pagerr \
		"Pas de login : l'authentification a �chou�."
    }

    #
    # R�cup�ration des param�tres du formulaire
    #

    if {[string length $form] > 0} then {
	if {[llength [::webapp::get-data ftab $form]] == 0} then {
	    ::webapp::error-exit $pagerr \
		"Formulaire non conforme aux sp�cifications"
	}
    }

    return
}
