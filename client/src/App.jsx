import { useCallback, useEffect, useState } from "react";
import { api } from "./api.js";
import {
  StatCards,
  DataTable,
  BatchForm,
  RecoveryForm,
} from "./components.jsx";

export default function App() {
  // All server data lives in one state object; one load() refreshes it.
  const [data, setData] = useState(null);
  const [msg, setMsg] = useState({ text: "", ok: true });

  const load = useCallback(async () => {
    const [
      stats,
      facilityReport,
      materialReport,
      batches,
      facilities,
      materials,
    ] = await Promise.all([
      api("/api/stats"),
      api("/api/reports/facility-recovery"),
      api("/api/reports/material-totals"),
      api("/api/batches"),
      api("/api/facilities"),
      api("/api/materials"),
    ]);
    setData({
      stats,
      facilityReport,
      materialReport,
      batches,
      facilities,
      materials,
    });
  }, []);

  useEffect(() => {
    load().catch((e) => setMsg({ text: e.message, ok: false }));
  }, [load]);

  // Runs a write, shows success or the database's own error, then refreshes.
  // Returns true/false so forms know whether to clear themselves.
  const act = async (fn, successText) => {
    try {
      await fn();
      setMsg({ text: successText, ok: true });
      await load();
      return true;
    } catch (e) {
      setMsg({ text: e.message, ok: false });
      return false;
    }
  };

  if (!data) return <p className="loading">{msg.text || "Loading…"}</p>;

  const openBatches = data.batches.filter((b) => b.status !== "Completed");

  return (
    <>
      <header>
        <h1>EcoCycle</h1>
        <span>Recycling &amp; material recovery</span>
      </header>
      <main>
        <p className={`msg ${msg.ok ? "ok" : "err"}`} role="status">
          {msg.text}
        </p>

        <StatCards stats={data.stats} />

        <DataTable
          title="Recovery by facility"
          rows={data.facilityReport}
          columns={[
            { key: "facility_name", label: "Facility" },
            { key: "city", label: "City" },
            { key: "total_batches", label: "Batches" },
            { key: "total_recovered_kg", label: "Recovered (kg)" },
          ]}
        />

        <DataTable
          title="Materials recovered"
          rows={data.materialReport}
          columns={[
            { key: "material_name", label: "Material" },
            { key: "batches_involved", label: "Batches" },
            { key: "total_recovered", label: "Total (kg)" },
          ]}
        />

        <DataTable
          title="Recycling batches"
          rows={data.batches}
          columns={[
            { key: "batch_code", label: "Batch" },
            { key: "facility_name", label: "Facility" },
            { key: "status", label: "Status" },
            { key: "item_count", label: "Items" },
            { key: "recovered_weight_kg", label: "Recovered (kg)" },
          ]}
          action={(row) =>
            row.status === "Completed" ? null : (
              <button
                className="small"
                onClick={() =>
                  act(
                    () =>
                      api(`/api/batches/${row.batch_id}/complete`, {
                        method: "POST",
                      }),
                    `${row.batch_code} completed`,
                  )
                }
              >
                Complete
              </button>
            )
          }
        />

        <section>
          <h2>New batch</h2>
          <BatchForm
            facilities={data.facilities}
            onSubmit={(body) =>
              act(
                () => api("/api/batches", { method: "POST", body }),
                "Batch created",
              )
            }
          />
        </section>

        <RecoveryForm
          openBatches={openBatches}
          materials={data.materials}
          onSubmit={(body) =>
            act(
              () => api("/api/recoveries", { method: "POST", body }),
              "Recovery recorded",
            )
          }
        />
      </main>
    </>
  );
}
