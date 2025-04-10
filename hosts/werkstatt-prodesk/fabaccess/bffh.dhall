{- Main configuration file for bffh
 - ================================
 -
 - In this configuration file you configure almost all parts of how bffh operates, but most importantly:
 -      * Machines
 -      * Initiators and Actors
 -      * Which Initiators and Actors relate to which machine(s)
 -      * Roles and the permissions granted by them
 -}

-- The config is in the configuration format/language dhall. You can find more information about dhall over at
-- https://dhall-lang.org

-- (Our) Dhall is somewhat similar to JSON and YAML in that it expects a top-level object containing the
-- configuration values
{
    -- Configure the addresses and ports bffh listens on
    listens = [
        -- BFFH binds a port for every listen object in this array.
        -- Each listen object is of the format { address = <STRING>, port = <INTEGER> }
        -- If you don't specify a port bffh will use the default of `59661`
        -- 'address' can be a IP address or a hostname
        -- If bffh can not bind a port for the specified combination if will log an error but *continue with the remaining ports*
        { address = "::", port = Some 59661 }
    ],

    -- Configure TLS. BFFH requires a PEM-encoded certificate and the associated key as two separate files
    certfile = "/etc/bffh/snakeoil-cert.pem",
    keyfile = "/etc/bffh/snakeoil-key.pem",

    -- BFFH right now requires a running MQTT broker.
    mqtt_url = "tcp://host.containers.internal:1883",

    -- Path to the database file for bffh. bffh will in fact create two files; ${db_path} and ${db_path}.lock.
    -- BFFH will *not* create any directories so ensure that the directory exists and the user running bffh has write
    -- access into them.
    db_path = "/var/lib/bffh/db",

    -- Audit log path. Bffh will log state changes into this file, one per line.
    -- Audit log entries are for now JSON:
    -- {"timestamp":1641497361,"machine":"Testmachine","state":{"state":{"InUse":{"uid":"Testuser","subuid":null,"realm":null}}}}
    auditlog_path = "/tmp/bffh.audit",

    -- In dhall you can also easily import definitions from other files, e.g. you could write
    -- roles = ./roles.dhall
    

    -- Name of Space
    spacename = "FabAccess Local Test",

    -- URL of BFFH Instance
    instanceurl = "localtest.fab-access.org",



    roles = {
        Admin = {
            permissions =  [
                "TestEnv.Admin",
                "TestEnv.Manage.A",
                "TestEnv.Manage.B",
                "TestEnv.Manage.C",
                "TestEnv.Write.A",
                "TestEnv.Write.B",
                "TestEnv.Write.C",
                "TestEnv.Read.A",
                "TestEnv.Read.B",
                "TestEnv.Read.C",
                "TestEnv.Disclose.A",
                "TestEnv.Disclose.B",
                "TestEnv.Disclose.C"
            ]
        },

        ManageA = {
            permissions = [ "TestEnv.Manage.A" ]
        },
        ManageB = {
            permissions = [ "TestEnv.Manage.B" ]
        },
        ManageC = {
            permissions = [ "TestEnv.Manage.C" ]
        },

        UseA = {
            permissions = [ "TestEnv.Write.A" ]
        },
        UseB = {
            permissions = [ "TestEnv.Write.B" ]
        },
        UseC = {
            permissions = [ "TestEnv.Write.C" ]
        },

        ReadA = {
            permissions = [ "TestEnv.Read.A" ]
        },
        ReadB = {
            permissions = [ "TestEnv.Read.B" ]
        },
        ReadC = {
            permissions = [ "TestEnv.Read.C" ]
        },

        DiscloseA = {
            permissions = [ "TestEnv.Disclose.A" ]
        },
        DiscloseB = {
            permissions = [ "TestEnv.Disclose.B" ]
        },
        DiscloseC = {
            permissions = [ "TestEnv.Disclose.C" ]
        }
    },

    machines = {
        MachineA1 = {
            name = "MachineA1",
            description = "Description of MachineA1",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryA",
            
            disclose = "TestEnv.Disclose.A",
            read = "TestEnv.Read.A",
            write = "TestEnv.Write.A",
            manage = "TestEnv.Manage.A"
        },
        MachineA2 = {
            name = "MachineA2",
            description = "Description of MachineA2",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryA",
            
            disclose = "TestEnv.Disclose.A",
            read = "TestEnv.Read.A",
            write = "TestEnv.Write.A",
            manage = "TestEnv.Manage.A"
        },
        MachineA3 = {
            name = "MachineA3",
            description = "Description of MachineA3",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryA",
            
            disclose = "TestEnv.Disclose.A",
            read = "TestEnv.Read.A",
            write = "TestEnv.Write.A",
            manage = "TestEnv.Manage.A"
        },
        MachineA4 = {
            name = "MachineA4",
            description = "Description of MachineA4",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryA",
            
            disclose = "TestEnv.Disclose.A",
            read = "TestEnv.Read.A",
            write = "TestEnv.Write.A",
            manage = "TestEnv.Manage.A"
        },
        MachineA5 = {
            name = "MachineA5",
            description = "Description of MachineA5",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryA",
            
            disclose = "TestEnv.Disclose.A",
            read = "TestEnv.Read.A",
            write = "TestEnv.Write.A",
            manage = "TestEnv.Manage.A"
        },

        MachineB1 = {
            name = "MachineB1",
            description = "Description of MachineB1",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryB",
            
            disclose = "TestEnv.Disclose.B",
            read = "TestEnv.Read.B",
            write = "TestEnv.Write.B",
            manage = "TestEnv.Manage.B"
        },
        MachineB2 = {
            name = "MachineB2",
            description = "Description of MachineB2",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryB",
            
            disclose = "TestEnv.Disclose.B",
            read = "TestEnv.Read.B",
            write = "TestEnv.Write.B",
            manage = "TestEnv.Manage.B"
        },
        MachineB3 = {
            name = "MachineB3",
            description = "Description of MachineB3",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryB",
            
            disclose = "TestEnv.Disclose.B",
            read = "TestEnv.Read.B",
            write = "TestEnv.Write.B",
            manage = "TestEnv.Manage.B"
        },
        MachineB4 = {
            name = "MachineB4",
            description = "Description of MachineB4",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryB",
            
            disclose = "TestEnv.Disclose.B",
            read = "TestEnv.Read.B",
            write = "TestEnv.Write.B",
            manage = "TestEnv.Manage.B"
        },
        MachineB5 = {
            name = "MachineB5",
            description = "Description of MachineB5",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryB",
            
            disclose = "TestEnv.Disclose.B",
            read = "TestEnv.Read.B",
            write = "TestEnv.Write.B",
            manage = "TestEnv.Manage.B"
        },

        MachineC1 = {
            name = "MachineC1",
            description = "Description of MachineC1",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryC",
            
            disclose = "TestEnv.Disclose.C",
            read = "TestEnv.Read.C",
            write = "TestEnv.Write.C",
            manage = "TestEnv.Manage.C"
        },
        MachineC2 = {
            name = "MachineC2",
            description = "Description of MachineC2",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryC",
            
            disclose = "TestEnv.Disclose.C",
            read = "TestEnv.Read.C",
            write = "TestEnv.Write.C",
            manage = "TestEnv.Manage.C"
        },
        MachineC3 = {
            name = "MachineC3",
            description = "Description of MachineC3",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryC",
            
            disclose = "TestEnv.Disclose.C",
            read = "TestEnv.Read.C",
            write = "TestEnv.Write.C",
            manage = "TestEnv.Manage.C"
        },
        MachineC4 = {
            name = "MachineC4",
            description = "Description of MachineC4",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryC",
            
            disclose = "TestEnv.Disclose.C",
            read = "TestEnv.Read.C",
            write = "TestEnv.Write.C",
            manage = "TestEnv.Manage.C"
        },
        MachineC5 = {
            name = "MachineC5",
            description = "Description of MachineC5",
            wiki = "https://fab-access.readthedocs.io",
            category = "CategoryC",
            
            disclose = "TestEnv.Disclose.C",
            read = "TestEnv.Read.C",
            write = "TestEnv.Write.C",
            manage = "TestEnv.Manage.C"
        },
    },
    
    actors = {=},

    actor_connections = [] : List { machine : Text, actor : Text },

    initiators = {=},

    init_connections = [] : List { machine : Text, initiator : Text },
}
