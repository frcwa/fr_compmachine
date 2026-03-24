# fr_compmachine

`fr_compmachine` is a compensation machine script for FiveM/Qbox servers.

It lets admins build a compensation package (items/amounts), generate a unique redeem code, and give that code to a player.  
The player then redeems the code at the compensation machine prop in-game and receives the configured rewards.

## Features

- Admin command to open the compensation builder UI
- 10-character unique redemption codes
- Redeem machine prop with `ox_target` interaction
- One-time code redemption
- Database persistence for pending compensation codes
- Optional Discord logging for code creation and redemption
- Basic event token validation for protected server events

## Requirements

Make sure these resources are installed and started:

- `ox_lib`
- `ox_target`
- `ox_inventory`
- `oxmysql`

## Installation

1. Copy the `fr_compmachine` folder into your resources:
   - `resources/fr_compmachine`

2. Import SQL:
   - Run the contents of `sql.sql` in your server database.
   - This creates the `compensation_codes` table.

3. Configure the script:
   - Open `config.lua`
   - Set:
     - `Config.prop` (machine prop model)
     - `Config.compPropLocation` (vector4 position/heading)

4. (Optional) Configure Discord logging:
   - Open `server/logs.lua`
   - Set:
     - `LogsConfig.discordWebhook = 'YOUR_WEBHOOK_URL'`
   - Leave empty (`''`) to disable logs.

5. Ensure dependencies start before this resource in `server.cfg`, then start `fr_compmachine`:

```cfg
ensure ox_lib
ensure oxmysql
ensure ox_inventory
ensure ox_target
ensure fr_compmachine
```

6. Restart the server

## Usage

- Admin opens builder with:
  - `/comp`
- Admin adds reward rows and generates a code.
- Give the generated code to the player.
- Player uses the machine prop target option to open redeem UI.
- Player enters code and redeems rewards.

## Notes

- Codes are one-time use and deleted after successful redemption.
- If reward delivery fails for an entry, redemption stops and the player is notified.
- Large reward amounts are supported by server-side validation limits in `server/server.lua`.

## Troubleshooting

- **`/comp` does not open**
  - Check your ACE/admin permissions for the command.

- **Machine prop does not appear**
  - Check `Config.prop` model name.
  - Check `Config.compPropLocation`.
  - Confirm client resource started without errors.

- **Code does not redeem**
  - Verify SQL table exists and is accessible.
  - Check server console for script/runtime errors.
  - Confirm `ox_inventory` can add the requested reward entries.

- **Discord logs not sending**
  - Verify webhook URL in `server/logs.lua`.

# Join My Discord For Support https://discord.gg/bdrkE7peRC 