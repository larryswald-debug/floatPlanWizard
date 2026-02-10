/**
 * Copyright Since 2005 TestBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 * This is the base Application for the TestBox testing suite
 * Whenever you are running tests from within TestBox Core
 */
component {

	this.name = "TestBox Testing Suite FPW";
	this.sessionManagement = true;
	this.sessionTimeout = createTimeSpan( 0, 1, 0, 0 );
	this.setClientCookies = true;

}
