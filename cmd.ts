import { $ } from "bun"
import Watcher from "watcher"

async function main() {
  const args = Bun.argv
  const command = args[2]

  const currentFilePath = import.meta.url.replace("file://", "")
  const currentFolder = `${currentFilePath.replace("cmd.ts", "")}`
  const watcher = new Watcher(currentFolder, { recursive: true })
  switch (command) {
    case "run":
      watcher.on("change", async (event) => {
        if (event.endsWith(".zig")) {
          await $`tput reset && zig build run`
        }
      })
      break
    case undefined:
      console.log("No command provided")
      break
    default:
      console.log("Unknown command")
      break
  }
}

await main()
