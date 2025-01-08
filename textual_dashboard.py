#!/usr/bin/env python3
"""
A small Textual dashboard that shows real-time Docker container logs
in a high-contrast, green-on-black "Matrix-like" style.

Requirements:
  - textual==0.20.0  (or similar version that supports ComposeResult)
  - docker (Python SDK)
  - A working Docker daemon (for reading container logs)
  - A venv with these installed
"""

import asyncio
import docker
from textual.app import App, ComposeResult
from textual.widgets import Static, Header, Footer
from textual.reactive import reactive
from textual.containers import VerticalScroll


class ContainerLogsView(Static):
    """
    A widget to watch a single container's logs in real time, 
    displayed in green text on a black background.
    """

    logs_text: str = reactive("")

    def __init__(self, container_name: str) -> None:
        super().__init__()
        self.container_name = container_name
        self.docker_client = docker.from_env()
        self.task = None

    async def watch_logs(self):
        """Continuously read logs from the container, line by line."""
        try:
            container = self.docker_client.containers.get(self.container_name)
            # Stream logs, i.e. follow=True
            log_stream = container.logs(stream=True, follow=True, tail=10)

            for line in log_stream:
                text_line = line.decode("utf-8", errors="replace").rstrip("\n")
                # Append green color markup
                self.logs_text += f"[bold green]{text_line}[/bold green]\n"
                await asyncio.sleep(0.01)  # let event loop refresh
        except Exception as ex:
            self.logs_text += f"\n[yellow]Error reading logs from {self.container_name}: {ex}[/yellow]\n"

    def watch_logs_task(self):
        """Schedule the watch_logs coroutine as a background task."""
        if self.task is None:
            self.task = asyncio.create_task(self.watch_logs())

    def compose(self) -> ComposeResult:
        """
        We just yield ourselves (Static) but we'll update its content
        whenever logs_text changes.
        """
        yield self

    def on_mount(self) -> None:
        """
        Called when the widget is added to the app.
        Kick off the background task to read logs,
        and refresh the widget periodically.
        """
        self.watch_logs_task()
        self.set_interval(0.5, self.refresh_view)  # refresh 2x/sec

    def refresh_view(self):
        """Update our widget content with logs_text."""
        # Set the rich-text content of this Static
        self.update(self.logs_text)


class DockerMatrixApp(App):
    """Main Textual App to show Docker container logs in a matrix-like style."""

    CSS = """
    Screen {
        background: $black;
        color: $green;
    }
    /* optional dark theme overrides */
    /* Make logs scrollable */
    VerticalScroll {
        width: 1fr;
        height: 1fr;
        border: solid #00ff00;
        margin: 1;
        padding: 1;
    }
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.client = docker.from_env()

    def compose(self) -> ComposeResult:
        """Compose layout: a Header, a Footer, plus multiple logs views."""
        yield Header("Docker Matrix Dashboard", style="bold green on black")
        yield Footer()
        containers = self.client.containers.list()
        if not containers:
            yield Static("[green]No running containers found![/green]")
        else:
            # Put each logs view inside a scrollable container
            for cont in containers:
                with VerticalScroll():
                    yield Static(f"[bold cyan]{cont.name}[/bold cyan]")
                    yield ContainerLogsView(cont.name)

    async def on_mount(self) -> None:
        """Called once the app is mounted. Could do extra init if needed."""
        # For example, we could refresh container list periodically
        pass


if __name__ == "__main__":
    DockerMatrixApp().run()
