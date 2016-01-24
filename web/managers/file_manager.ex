defmodule Opencov.FileManager do
  use Opencov.Web, :manager
  import Opencov.File
  alias Opencov.File

  @required_fields ~w(name source coverage_lines)
  @optional_fields ~w(job_id)

  def changeset(model, params \\ :empty) do
    model
    |> cast(normalize_params(params), @required_fields, @optional_fields)
    |> generate_coverage
    |> prepare_changes(&set_previous_file/1)
  end

  defp normalize_params(%{"coverage" => coverage} = params) when is_list(coverage) do
    {lines, params} = Map.pop(params, "coverage")
    Map.put(params, "coverage_lines", lines)
  end
  defp normalize_params(params), do: params

  defp generate_coverage(changeset) do
    case get_change(changeset, :coverage_lines) do
      nil -> changeset
      lines -> put_change(changeset, :coverage, compute_coverage(lines))
    end
  end

  defp set_previous_file(changeset),
    do: set_previous_file(changeset, job_for_changeset(changeset))
  defp set_previous_file(changeset, %Opencov.Job{previous_job_id: previous_job_id})
      when not is_nil(previous_job_id) do
    file = find_previous_file(previous_job_id, changeset.changes.name)
    set_previous_file(changeset, file)
  end
  defp set_previous_file(changeset, %Opencov.File{id: id, coverage: coverage}),
    do: change(changeset, previous_file_id: id, previous_coverage: coverage)
  defp set_previous_file(changeset, _), do: changeset

  defp job_for_changeset(changeset) do
    job_id = get_change(changeset, :job_id) || changeset.model.job_id
    Repo.get(Opencov.Job, job_id)
  end

  defp find_previous_file(previous_job_id, name) do
    File |> for_job(previous_job_id) |> query_with_name(name) |> Opencov.Repo.one
  end
end
