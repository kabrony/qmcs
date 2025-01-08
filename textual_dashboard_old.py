#!/usr/bin/env python3
"""
A legacy Textual (pre-ComposeResult) "Matrix style" Docker logs viewer
that should work with textual==0.1.18 or similar older textual releases.
"""

import asyncio
import docker
from textual.app import App
from textual import events
from textual.widgets import Header, Footer, ScrollView, Static
from textual.views import DockView
from textual.reactive import Reactive


class ContainerLogsView(Static):
    """
    A widget that watches logs for one container, displayed in green text.
    """

    logs_text: Reactive[str] = Reactive("")

    def __init__(self, container_name: str, **kwargs):
        super().__init__(**kwargs)
        self.container_name = container_name
        self.client = docker.from_env()
        self.log_task = None

    async def watch_logs(self):
        """Continuously read logs from Docker container and append them."""
        try:
            container = self.client.containers.get(self.container_name)
            for line in container.logs(stream=True, follow=True, tail=10):
                text_line = line.decode("utf-8", errors="replace").rstrip("\n")
                # color each line green
                self.logs_text += f"[bold green]{text_line}[/bold green]\n"
                # let UI update
                await asyncio.sleep(0.01)
        except Exception as ex:
            self.logs_text += (
                f"\n[yellow]Error reading logs for {self.container_name}: {ex}[/yellow]\n"
            )

    def on_mount(self):
        """Called when widget is mounted. Start the background log reading."""
        if not self.log_task:
            self.log_task = asyncio.create_task(self.watch_logs())

    def watch(self) -> None:
        """Update the widget content with logs_text whenever it changes."""
        self.update(self.logs_text)

    def render(self) -> str:
        """
        Called automatically, returns the text to display.
        We'll just return logs_text, which includes markup.
        """
        return self.logs_text

    def watch_logs_text(self, old_value: str, new_value: str) -> None:
        """
        Called automatically by `Reactive`, whenever logs_text changes.
        We'll update the widget to reflect new text lines.
        """
        self.refresh()


class DockerMatrixApp(App):
    """A simple older-style Textual app with DockView."""

    async def on_load(self, event: events.Load) -> None:
        """Set a title, allow quitting with 'q' or Ctrl-C."""
        await self.bind("q", "quit", "Quit")

    async def on_mount(self, event: events.Mount) -> None:
        """
        Create a DockView, place a Header on top, a Footer on bottom,
        and for each container, a ScrollView with a ContainerLogsView.
        """
        self.title = "Docker Matrix (Legacy Textual)"

        # main layout container
        self.view = DockView()
        await self.push_view(self.view)

        # top header
        header = Header(tall=False, style="bold green on black")
        await self.view.dock(header, edge="top")

        # bottom footer
        footer = Footer()
        await self.view.dock(footer, edge="bottom")

        # get running containers
        client = docker.from_env()
        containers = client.containers.list()

        if not containers:
            # show a single message
            no_container_msg = Static("[green]No running containers![/green]")
            await self.view.dock(no_container_msg, edge="top")
        else:
            # for each container, create a scroll area with logs
            for cont in containers:
                scroll = ScrollView()
                logs_view = ContainerLogsView(cont.name)
                await scroll.update(logs_view)
                await self.view.dock(scroll, size=20)

    async def handle_background_tasks(self):
        """Optional method to do periodic container refresh if needed."""
        pass


if __name__ == "__main__":
    DockerMatrixApp.run(title="Docker Legacy Matrix", log="textual.log")
