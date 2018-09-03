#!/bin/bash
export GOBIN=${GOPATH}/bin
systemd_manager ()  # Skywire Manager (autostart) configuration
{    # need to test, doesnt work on windows bash
    local manager=`
    `"${GOPATH}/src/github.com/skycoin/skywire/static/skywire-manager"

    # systemd service file
    printf "[Unit]\n`
        `Description=Skywire Manager\n`
        `After=network.target\n`
        `\n`
        `[Service]\n`
        `WorkingDirectory=$GOBIN\n`
        `Environment=\"GOPATH="$GOPATH"\" \"GOBIN=${GOPATH}/bin\"\n`
        `ExecStart=${GOBIN}/manager -web-dir "$manager"\n`
        `ExecStop=kill\n`
        `Restart=on-failure\n`
        `RestartSec=10\n`
        `\n`
        `[Install]\n`
        `WantedBy=multi-user.target\n" > /etc/systemd/system/skymanager.service
}
systemd_node () # Skywire Node (autostart) configuration
{
    local disc_addr="discovery.skycoin.net:"`
    `"5999-034b1cd4ebad163e457fb805b3ba43779958bba49f2c5e1e8b062482904bacdb68"

    # systemd service file
    printf "[Unit]\n`
        `Description=Skywire Node\n`
        `After=network.target\n`
        `\n`
        `[Service]\n`
        `WorkingDirectory=$GOBIN\n`
        `Environment=\"GOPATH="$GOPATH"\" \"GOBIN=${GOPATH}/bin\"\n`
        `ExecStart=${GOBIN}/node -connect-manager ${IP_MANAGER}:5998 ` \
        `-manager-web ${IP_MANAGER}:8000 -discovery-address "$disc_addr" ` \
        `-address :5000 -web-port :6001\n`
        `ExecStop=kill\n`
        `Restart=on-failure\n`
        `RestartSec=10\n`
        `\n`
        `[Install]\n`
        `WantedBy=multi-user.target\n" > /etc/systemd/system/skynode.service
}
systemctl daemon-reload
systemctl enable skymanager.service
systemctl start skymanager.service