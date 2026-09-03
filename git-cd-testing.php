<?php
/**
 * Plugin Name:       Git CD Testing
 * Plugin URI:        https://example.com/git-cd-testing
 * Description:       Minimal plugin used to test git-based continuous delivery. Implements activation and deactivation modes only.
 * Version:           1.0.0
 * Requires at least: 5.0
 * Requires PHP:      7.0
 * Author:            Abu Sohib
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       git-cd-testing
 */

// Exit if accessed directly.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'GIT_CD_TESTING_VERSION', '1.0.0' );
define( 'GIT_CD_TESTING_OPTION', 'git_cd_testing_state' );

/**
 * Runs on plugin activation.
 *
 * Stores the activation state so a deploy can be verified from the database.
 */
function git_cd_testing_activate() {
	update_option(
		GIT_CD_TESTING_OPTION,
		array(
			'status'        => 'active',
			'version'       => GIT_CD_TESTING_VERSION,
			'activated_at'  => current_time( 'mysql' ),
		)
	);
}
register_activation_hook( __FILE__, 'git_cd_testing_activate' );

/**
 * Runs on plugin deactivation.
 *
 * Flips the stored state to inactive; the option itself is left in place so the
 * last deactivation timestamp remains inspectable.
 */
function git_cd_testing_deactivate() {
	$state = get_option( GIT_CD_TESTING_OPTION, array() );

	if ( ! is_array( $state ) ) {
		$state = array();
	}

	$state['status']         = 'inactive';
	$state['version']        = GIT_CD_TESTING_VERSION;
	$state['deactivated_at'] = current_time( 'mysql' );

	update_option( GIT_CD_TESTING_OPTION, $state );
}
register_deactivation_hook( __FILE__, 'git_cd_testing_deactivate' );

