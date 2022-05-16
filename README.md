# WyeWorks Exercise

## Goal

Given a txt with Bob Dylan's discography info (year album_title), create a Trello Album Board sorted by decade-year-title
  and provide the album cover if it exists in Spotify.


You can read all the exercise details in [prueba tecnica.pdf](/prueba%20tecnica.pdf)

## Requirements

1. This scripts requires Elixir; if you have not yet installed it, please do so with the instructions given at [Elixir docs](https://elixir-lang.org/install.html)

## Use

1. Create a `.env` file and provide your Spotify and Trello environment variables ([.env-sample](/.env-sample) file lists all the variables required). This file should be placed in the project's root directory (for security, it is highly recommended to .gitignore this file)

2. You'll need to do `source .env` in the terminal where you will run the script. You may prefer do this from your `.bash_profile` or similar file to make sure it's available every terminal session.

3. In the project root directory run `elixir ww_exercise.exs`, and wait for the terminal to print the Trello board url:

    ```
    A. 📗 Reading and parsing txt...
    B. 🖼️  Fetching album covers from Spotify...
    C. 🗂️  Sorting albums...
    D. 📃 Creating decade lists...
    E. 🎼 Populating list with album cards...

    🎉🎉 Your Bob Dylan’s Trello Board is ready! Please visit <your_trello_board_url_here> 🚀🚀
    ```

## May I see a preview?

Of course! You can see the script running in this [video example](/ww-script-example.mp4)
