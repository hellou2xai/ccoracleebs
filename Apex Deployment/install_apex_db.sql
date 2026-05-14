-- ============================================================================
-- U2xAI EBS Agentic Apps — Install APEX into Oracle Database
-- ============================================================================
-- Run as SYS:
--   sqlplus sys/password@//140.245.24.128:1521/EBSDB as sysdba
--
-- This script handles:
--   1. Check if APEX is already installed
--   2. Install APEX (if needed)
--   3. Configure REST users
--   4. Create workspace
--   5. Create workspace admin
-- ============================================================================

SET SERVEROUTPUT ON

-- ─── Check if APEX is installed ────────────────────────────────────────────
DECLARE
    v_version VARCHAR2(100);
    v_installed BOOLEAN := FALSE;
BEGIN
    BEGIN
        SELECT version_no INTO v_version
        FROM apex_release
        WHERE ROWNUM = 1;
        v_installed := TRUE;
        DBMS_OUTPUT.PUT_LINE('APEX already installed: version ' || v_version);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('APEX is NOT installed.');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('To install APEX:');
            DBMS_OUTPUT.PUT_LINE('  1. Download from https://www.oracle.com/tools/downloads/apex-downloads/');
            DBMS_OUTPUT.PUT_LINE('  2. Extract to C:\apex');
            DBMS_OUTPUT.PUT_LINE('  3. Connect as SYS:');
            DBMS_OUTPUT.PUT_LINE('     sqlplus sys/password@//140.245.24.128:1521/EBSDB as sysdba');
            DBMS_OUTPUT.PUT_LINE('  4. Run:');
            DBMS_OUTPUT.PUT_LINE('     @C:\apex\apexins.sql SYSAUX SYSAUX TEMP /i/');
            DBMS_OUTPUT.PUT_LINE('  5. Wait 20-45 minutes for installation to complete');
            DBMS_OUTPUT.PUT_LINE('  6. Then re-run this script');
    END;

    IF NOT v_installed THEN
        RETURN;
    END IF;

    -- ─── Unlock and configure APEX accounts ────────────────────────────────
    DBMS_OUTPUT.PUT_LINE('Configuring APEX database accounts...');

    BEGIN
        EXECUTE IMMEDIATE 'ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK';
        EXECUTE IMMEDIATE q'[ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "OracleApex1!"]';
        DBMS_OUTPUT.PUT_LINE('  APEX_PUBLIC_USER: unlocked');
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  APEX_PUBLIC_USER: ' || SQLERRM);
    END;

    BEGIN
        EXECUTE IMMEDIATE 'ALTER USER APEX_REST_PUBLIC_USER ACCOUNT UNLOCK';
        EXECUTE IMMEDIATE q'[ALTER USER APEX_REST_PUBLIC_USER IDENTIFIED BY "OracleRest1!"]';
        DBMS_OUTPUT.PUT_LINE('  APEX_REST_PUBLIC_USER: unlocked');
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  APEX_REST_PUBLIC_USER: ' || SQLERRM);
    END;

    BEGIN
        EXECUTE IMMEDIATE 'ALTER USER APEX_LISTENER ACCOUNT UNLOCK';
        EXECUTE IMMEDIATE q'[ALTER USER APEX_LISTENER IDENTIFIED BY "OracleRest1!"]';
        DBMS_OUTPUT.PUT_LINE('  APEX_LISTENER: unlocked');
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  APEX_LISTENER: ' || SQLERRM);
    END;

    -- ─── Set APEX admin password ───────────────────────────────────────────
    DBMS_OUTPUT.PUT_LINE('Setting APEX ADMIN password...');
    BEGIN
        APEX_UTIL.SET_SECURITY_GROUP_ID(10);
        -- Check if ADMIN exists
        BEGIN
            APEX_UTIL.SET_PASSWORD(
                p_user_name => 'ADMIN',
                p_password  => 'Admin123!'
            );
            DBMS_OUTPUT.PUT_LINE('  ADMIN password updated.');
        EXCEPTION
            WHEN OTHERS THEN
                APEX_UTIL.CREATE_USER(
                    p_user_name       => 'ADMIN',
                    p_email_address   => 'admin@u2xai.com',
                    p_web_password    => 'Admin123!',
                    p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
                    p_change_password_on_first_use => 'N'
                );
                DBMS_OUTPUT.PUT_LINE('  ADMIN user created.');
        END;
        COMMIT;
    END;

    -- ─── Create workspace ──────────────────────────────────────────────────
    DBMS_OUTPUT.PUT_LINE('Creating workspace U2XEBS...');
    BEGIN
        APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
            p_workspace      => 'U2XEBS',
            p_primary_schema => USER
        );
        DBMS_OUTPUT.PUT_LINE('  Workspace U2XEBS created.');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 OR INSTR(SQLERRM, 'already exists') > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Workspace U2XEBS already exists.');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  Workspace error: ' || SQLERRM);
            END IF;
    END;

    -- ─── Create workspace developer user ───────────────────────────────────
    BEGIN
        APEX_UTIL.SET_WORKSPACE('U2XEBS');
        APEX_UTIL.CREATE_USER(
            p_user_name       => 'ADMIN',
            p_email_address   => 'admin@u2xai.com',
            p_web_password    => 'Admin123!',
            p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
            p_change_password_on_first_use => 'N'
        );
        DBMS_OUTPUT.PUT_LINE('  Workspace ADMIN user created.');
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  Workspace user: ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('APEX database setup complete.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Next steps:');
    DBMS_OUTPUT.PUT_LINE('  1. Install ORDS (run setup_ords.bat)');
    DBMS_OUTPUT.PUT_LINE('  2. Start ORDS (run start_ords.bat)');
    DBMS_OUTPUT.PUT_LINE('  3. Deploy app (run deploy_app.bat)');
    DBMS_OUTPUT.PUT_LINE('  4. Import 05_apex_app.sql via App Builder');
    DBMS_OUTPUT.PUT_LINE('=============================================');
END;
/
