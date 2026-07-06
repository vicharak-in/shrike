import sys

from PyQt6.QtWidgets import QApplication

from main_window import MainWindow

from styles import APP_STYLE


def main():

    app = QApplication(sys.argv)

    app.setStyleSheet(APP_STYLE)

    window = MainWindow()

    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()