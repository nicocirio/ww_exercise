Mix.install([:trello, :httpoison])
Application.put_env(:trello, :app_key, {:system, "WW_TRELLO_APP_KEY"})

defmodule TxtToTrello do
  @moduledoc """
  Given a txt with Bob Dylan's discography info (year album_title), it creates a Trello Board sorted by decade-year-title
  and provides the album cover if it exists in Spotify.
  """
  @trello_app_key System.get_env("WW_TRELLO_APP_KEY")
  @trello_token System.get_env("WW_TRELLO_TOKEN")
  @spotify_client_id System.get_env("WW_SPOTIFY_CLIENT_ID")
  @spotify_client_secret System.get_env("WW_SPOTIFY_CLIENT_SECRET")

  def run_script() do
    # early return if there are no more free trello boards available in the user Account
    {board_id, board_url} = create_blank_trello_board()

    read_and_parse_txt("discography.txt")
    |> maybe_add_spotify_album_covers()
    |> sort_albums()
    |> populate_board(board_id, board_url)
  end

  @spec read_and_parse_txt(String.t()) :: list(Tuple.t())
  defp read_and_parse_txt(txt_path) do
    IO.puts("A. 📗 Reading and parsing txt...")

    File.read!(txt_path)
    |> String.split("\n", trim: true)
    |> Enum.map(fn album ->
      {year, title} = String.split_at(album, 4)

      {decade_from_year(year), year, String.trim(title), nil}
    end)
  end

  @spec maybe_add_spotify_album_covers(list(Tuple.t())) :: list(Tuple.t())
  defp maybe_add_spotify_album_covers(albums) do
    IO.puts("B. 🖼️  Fetching album covers from Spotify...")

    {:ok, spotify_token} = get_spotify_token()

    Enum.map(albums, fn {decade, year, title, _url} ->
      cover_image_url = query_spotify_album_for_cover_url(spotify_token, title, year)

      sorting_key = decade <> year <> title
      {sorting_key, decade, year, title, cover_image_url}
    end)
  end

  @spec sort_albums(list(Tuple.t())) :: list(Tuple.t())
  defp sort_albums(albums) do
    IO.puts("C. 🗂️  Sorting albums...")

    albums
    |> Enum.sort_by(fn {sorting_key, _decade, _year, _title, _cover_image_url} -> sorting_key end)
    |> Enum.map(fn {_sorting_key, decade, year, title, cover_image_url} ->
      {decade, year, title, cover_image_url}
    end)
  end

  @spec populate_board(list(Tuple.t()), String.t(), String.t()) :: String.t()
  defp populate_board(albums, board_id, board_url) do
    IO.puts("D. 📃 Creating decade lists...")
    decade_lists_map = create_decade_lists(albums, board_id)
    # %{"decade_list_name" => list_id}

    IO.puts("E. 🎼 Populating list with album cards...")
    populate_decade_lists_with_album_cards(albums, decade_lists_map)

    IO.puts("\n🎉🎉 Your Bob Dylan’s Trello Board is ready! Please visit #{board_url} 🚀🚀\n")
  end

  defp create_blank_trello_board() do
    case Trello.post("boards", %{name: "Bob Dylan’s discography"}, @trello_token) do
      {:ok, %{id: board_id, short_url: board_url}} ->
        close_default_board_lists(board_id)
        {board_id, board_url}

      {:ok, %{message: "Board must be in a team — specify an idOrganization"}} ->
        IO.puts("""
        \n😲 Oops! It seems you have any free Trello boards left.
        Please manually delete a board from your Trello account and re-run this script.
        """)

        exit(:shutdown)

      {:error, "invalid key"} ->
        IO.puts("""
        Please provide Trello app-key and token in the '.env' file and re-run this script.
        🤔 Or maybe you forgot to 'source .env'?
        More info in the README file.
        """)

        exit(:shutdown)
    end
  end

  defp close_default_board_lists(board_id) do
    {:ok, default_lists} = Trello.get_board_lists(board_id, @trello_token)

    spawn(fn ->
      Enum.each(default_lists, fn default_list ->
        url =
          "https://api.trello.com/1/lists/#{default_list.id}/closed?value=true&key=#{@trello_app_key}&token=#{@trello_token}"

        {:ok, _http_response} = HTTPoison.put(url)
      end)
    end)
  end

  defp decade_from_year(year) do
    String.slice(year, 0, 3) <> "0" <> " Decade"
  end

  @spec create_decade_lists(List.t(), String.t()) :: Map.t()
  defp create_decade_lists(albums, board_id) do
    decade_list_headers =
      albums
      |> Enum.uniq_by(fn {decade, _year, _title, _url} -> decade end)
      |> Enum.map(fn {decade, _year, _title, _url} -> decade end)
      |> Enum.reverse()

    Enum.reduce(decade_list_headers, %{}, fn list_header, acum ->
      {:ok, list} = Trello.post("lists", %{name: list_header, idBoard: board_id}, @trello_token)
      Map.merge(acum, %{"#{list.name}" => list.id})
    end)
  end

  defp populate_decade_lists_with_album_cards(albums, decade_lists_map) do
    Enum.each(albums, fn {decade, year, title, url} ->
      decade_list_id = decade_lists_map["#{decade}"]
      card_name = year <> " - " <> title
      create_card_in_list(card_name, decade_list_id, url)
    end)
  end

  defp create_card_in_list(card_name, decade_list_id, nil) do
    Trello.post(
      "cards",
      %{name: card_name, idList: decade_list_id},
      @trello_token
    )
  end

  defp create_card_in_list(card_name, decade_list_id, url) do
    {:ok, %{id: card_id}} =
      Trello.post(
        "cards",
        %{name: card_name, idList: decade_list_id},
        @trello_token
      )

    spawn(fn ->
      set_attachment_as_card_cover(card_id, url)
    end)
  end

  defp set_attachment_as_card_cover(card_id, url) do
    Trello.post(
      "cards/#{card_id}/attachments",
      %{url: url, setCover: true},
      @trello_token
    )
  end

  defp get_spotify_token() do
    url = "https://accounts.spotify.com/api/token"

    headers = [
      {"Authorization",
       "Basic " <> Base.encode64("#{@spotify_client_id}:#{@spotify_client_secret}")},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body = "grant_type=client_credentials"

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body = Poison.decode!(body)
        {:ok, body["access_token"]}

      {:ok, %HTTPoison.Response{status_code: _, body: body}} ->
        body = Poison.decode!(body)
        IO.puts("\nCould not access Spotify API: #{body["error"]}\n")
        exit(:shutdown)

      {:error, "invalid_client"} ->
        IO.puts(
          "\nPlease provide Spotify client-id and client-secret in the '.env' file and re-run this script\n"
        )

        exit(:shutdown)
    end
  end

  defp query_spotify_album_for_cover_url(spotify_token, title, year, artist \\ "Bob Dylan") do
    url =
      "https://api.spotify.com/v1/search?q=artist:#{artist}+year:#{year}+album:#{title}&type=album"
      |> URI.encode()

    headers = [
      {"Authorization", "Bearer " <> spotify_token},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        maybe_get_url_album_cover(body)

      {:ok, %HTTPoison.Response{status_code: _, body: body}} ->
        body = Poison.decode!(body)
        {:error, body["error"]}
    end
  end

  defp maybe_get_url_album_cover(body) do
    case Poison.decode!(body) do
      %{"albums" => %{"total" => 1} = albums} ->
        unique_item_result = albums["items"] |> hd
        image = unique_item_result["images"] |> hd

        image["url"]

      %{"albums" => %{"total" => _}} ->
        nil
    end
  end
end

TxtToTrello.run_script()
