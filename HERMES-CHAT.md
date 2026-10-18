# Hermes chat

Build 15 adds a native Chat destination alongside Work and Wallet. It connects to a normal Hermes gateway's authenticated Sessions API over the existing embedded Tailscale route. Wallet custody, Devgraph grants and Hermes gateway authorization remain separate.

## On the iPhone

Open **Chat → Connection**. Choose the private connection file supplied by the gateway operator, or enter the gateway's HTTPS origin and connection key. Join the same Tailscale network, then choose **Connect to Hermes**. Connection checks discover API support without sending a prompt. Send the first message to create a conversation.

Chat and Work share the app's private network. Disconnecting it pauses both; neither silently retries through the public network. Work's existing HTTP timeouts retain their defaults; a chat turn permits a longer bounded wait for the final reply.

The gateway key, session reference and pending-message marker are stored together in a non-synchronizing, device-only Keychain item accessible while the iPhone is unlocked. They do not enter Wallet custody, recovery files or data exports. Chat text is not persisted by Zenith; history remains on the selected Hermes profile. Locking, backgrounding or leaving Chat cancels HTTP and clears displayed messages and in-memory authorization. Unlocking/reopening loads the conversation from the gateway.

A connection file contains the **private gateway key**. Keep it private and remove the transfer copy from Files after importing if desired. Import previews its settings; only Connect saves them. Changing the receiver requires its own key and does not carry a conversation to another server.

```json
{
  "schema": "zenith.hermes-chat.v1",
  "name": "My Hermes",
  "receiver": "https://your-mac.your-tailnet.ts.net:10443",
  "key": "<private API_SERVER_KEY>"
}
```

There are no built-in server addresses, provider credentials or keys. The gateway key authorizes the selected Hermes profile; it is not a Castalia-issued credential and must never be substituted for Devgraph read authority.

## Conversation behavior

This first version supports text, completed assistant replies, conversation refresh and New chat. It uses `GET /v1/capabilities`, `POST /api/sessions`, session history and synchronous session chat. Hermes retains full server-side context, including tool work; Zenith only renders user and final assistant text. Streaming, attachments, voice and tool-approval UI are follow-ups.

A pending marker is saved before sending. Network loss or backgrounding never automatically resubmits the prompt. Refresh checks the existing history. If a reply remains unresolved, the app asks the person to refresh or explicitly start a new conversation; New chat does not stop server work or delete old conversations. Server-side compression/restart can require a fresh conversation when a pending result cannot be reconciled. This is not an exactly-once execution protocol.

Redirects, cleartext origins, keys in URLs, invalid session paths and oversized replies are rejected. Error bodies and tool outputs are not displayed as authorization diagnostics. Existing gateway tool-approval policies are not bypassed.

## Gateway setup

Use a dedicated standard Hermes profile with its own API key, history and optional personality. Enable only the API server, bind it to loopback, and expose a separately chosen tailnet-only HTTPS route with Tailscale Serve. Preserve existing routes and do not enable Funnel for this endpoint. The operator supplies the private connection file out of band.

The implementation was exercised against the installed Hermes stable 0.20.0 gateway, using its configured provider. For this runtime, `platforms.api_server.extra.model_name` is set to that profile's actual configured model so newly created sessions do not accidentally select the profile-name alias as an upstream model. The dedicated macOS service uses standard Application Support/Logs locations. No Hermes source fork is needed.

## Verification

Swift tests cover authenticated session calls, mixed-type capability flags, filtering system/tool traffic, unsafe connection files and session paths, and authentication/redirect denial. Existing private-network lifecycle tests cover cancellation and the absence of a direct fallback.

Set `HERMES_CHAT_TEST_PROFILE` to an explicitly selected private connection file to run the optional real gateway test. It creates a disposable server conversation, asks for a harmless fixed reply without tools, and verifies history through the actual Swift client. No connection key is logged or stored in test artifacts. Without that explicit input the live check is skipped.

Record source and build hashes separately from gateway and iPhone results. A successful native Swift HTTPS test is not physical-device or embedded Tailscale enrollment evidence. Phone import, Keychain access, real private routing, background/resume and accessibility remain device checks.

## Tailscale auth-key enrollment — build 16

In Chat → Connection (or Work → Connection), choose **Sign in with an auth key** in the Tailscale section. Paste a `tskey-auth-…` key, or choose a text file containing only the key, then choose **Enroll this iPhone**. Obtain a one-time key from your tailnet administrator with Reusable off and Ephemeral off; a pre-approved key skips device approval where permitted. Zenith cannot determine those server-side key settings from the opaque key. Device approval and Tailnet Lock policies still apply.

This enrolls the existing installation-local Tailscale node using the official control plane. It does not switch an already-authorized node to another account. Existing browser sign-in, saved Work/Hermes connection files, custody and grants remain compatible. No control-plane address or key is bundled. Tailscale API tokens, OAuth secrets and the Hermes gateway key are not enrollment keys. The imported file is bounded to 1 KiB; keys are validated before interrupting an existing connection.

The form clears its input on submit, dismissal and inactivity. The enrollment key is passed transiently to the embedded Tailscale runtime and is not stored in Zenith preferences, Keychain, Wallet backups or logs. Its lifetime inside the native runtime lasts until that node is closed. Saved protected Tailscale device state supplies future reconnects; foreground resume never resubmits the enrollment key. A failed or interrupted attempt requires deliberate resubmission, and a consumed one-time key may need replacing. The source file, if used, remains in Files for the user to remove. Auth-key expiry is separate from device-key expiry.

Validation includes parser bounds/token rejection and network lifecycle tests for key-only enrollment, cancellation, error redaction, and saved-identity resume without replay. Actual tailnet enrollment requires a valid administrator-supplied key and physical-device acceptance.

## Voice to text — build 17

Tap the microphone beside the Chat message field to dictate. The first use asks for microphone and speech-recognition permission. Zenith uses the iPhone’s current locale and requires Apple’s on-device speech support; unsupported languages/devices show a message and retain typed input. There is no automatic server recognition fallback or audio upload to Hermes. The existing iOS 18.1 minimum is retained, including support for the current iOS 18.5 development phone.

Partial transcription appears in the composer after any text already entered. Tap Stop, wait for finalization, review/edit and tap Send yourself. Sending is disabled while recording/finalizing. Discard dictation restores the draft from before recording. Recording stops after 55 seconds, with up to three more seconds for a final transcript; a late callback cannot overwrite reviewed text. Recognition failures retain captured partial text for review. No audio file is written. Voice replies, audio messages, background capture and streaming microphone audio to the gateway are out of scope.

Recording is cancelled on audio interruptions/route changes. Leaving Chat, changing the private connection, backgrounding or locking cancels capture and clears the transient draft. System permission dialogs are allowed to finish, but cancelling authorization or leaving the view prevents a delayed permission callback from starting capture. Permission denial, unavailable language assets, real microphone input/route behavior and speech accuracy require physical-device acceptance; mocked lifecycle tests do not qualify them.
