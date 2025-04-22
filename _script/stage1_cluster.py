import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.cluster import KMeans
from scipy.spatial import distance
import os
from utils.cluster import ClusterAttr

"""This script is used to generate the cluster analysis. 
Noted that the cluster type generated may have different order from the paper."""


def get_color_palette(n):
    color_palette = sns.color_palette("husl", n)
    color_dict = dict(zip(range(n), color_palette))
    return color_palette, color_dict


DATA_FOLDER = "../_data/"
GRAPHIC_PATH = "../_graphic/"
os.makedirs(GRAPHIC_PATH, exist_ok=True)
## SET UP CONSTANTS
RES = 9  # this is the h3 index resolution
N_CAT = 27  # this is the original categories of street view features (not all are used in the analysis)
PREFIXFULL = "_built_environment"
FILENAME_WITHIN = "c_seg_cat={N_CAT}_res={res}_withincity{prefixfull}_tsne.parquet"
FILENAME_ORI_WITHIN = "c_seg_cat={N_CAT}_res={res}_withincity.parquet"
CLUSTER_RANGE = [4, 5, 6, 7, 8]

# SET UP VIZ FEATURES
variables_sel_top1_order = ClusterAttr.variables_sel_top1_order
variables_sel_top1_order_all = ClusterAttr.variables_sel_top1_order_all
len(variables_sel_top1_order)
variables_sel_order = ClusterAttr.variables_sel_order


def plot_wss_kmean(data, N, comment):
    """Try Kmean instead"""

    wss = []
    distorsions = []

    for i in range(2, N):
        print("cluster: ", i)
        # fcm_vol = FCM(n_clusters=i, random_state=0)
        km = KMeans(n_clusters=i, random_state=0)
        km.fit(data)
        wss.append(km.inertia_)
        distorsions.append(
            sum(np.min(distance.cdist(data, km.cluster_centers_, "euclidean"), axis=1))
            / data.shape[0]
        )
        # silhouette.append(silhouette_score(data, km.labels_))

    sns.set(style="whitegrid")
    sns.set_context(
        "paper", rc={"font.size": 10, "axes.titlesize": 12, "axes.labelsize": 12}
    )

    fig, axes = plt.subplots(1, 2, figsize=(12, 4))
    ax1, ax2 = axes
    ax1.plot(range(2, N), wss, "bx-", color="black")
    # make sure the x-axis is in integers
    ax1.set_xticks(np.arange(2, N, step=1))
    ax1.set_xlabel("Number of clusters $K$")
    ax1.set_ylabel("Inertia")
    ax1.set_title("The Elbow Method showing the optimal $K$")

    ax2.plot(range(2, N), distorsions, "bx-", color="black")
    # make sure the x-axis is in integers
    ax2.set_xticks(np.arange(2, N, step=1))
    ax2.set_xlabel("Number of clusters $K$")
    ax2.set_ylabel("Distorsion")
    ax2.set_title("The Elbow Method showing the optimal $K$")
    fig.savefig(
        os.path.join(GRAPHIC_PATH, f"elbow_silhouette_volume_{N}{comment}.png"),
        dpi=200,
        bbox_inches="tight",
    )
    plt.show()

    return wss, distorsions


def generate_cluster(prefixfull, res=RES):
    df_seg_summary = pd.read_csv(
        os.path.join(DATA_FOLDER, "c_exposure_sidewalk_h3.csv")
    )
    df_within = pd.read_parquet(
        os.path.join(
            DATA_FOLDER,
            FILENAME_WITHIN.format(res=res, prefixfull=prefixfull, N_CAT=N_CAT),
        )
    )
    df_ori_within = pd.read_parquet(
        os.path.join(
            DATA_FOLDER,
            FILENAME_ORI_WITHIN.format(res=res, N_CAT=N_CAT, prefixfull=prefixfull),
        )
    )
    print("original size:", df_within.shape[0])
    # filter out hex with too few images (fewer than 10 images)
    df_within = df_within[df_within["img_count"] > 4].reset_index(drop=True)
    print("after dropping size:", df_within.shape[0])

    # only keep the hex with exposure indicator > 0
    df_with_exposure = df_seg_summary[
        df_seg_summary["exposure_indicator"] > 0
    ].reset_index(drop=True)
    df_with_exposure_within = df_within[
        df_within["hex_id"].isin(df_with_exposure["h3_9"].unique())
    ].reset_index(drop=True)
    print("after dropping size:", df_with_exposure_within.shape[0])
    data = df_with_exposure_within[["tsne_1", "tsne_2"]].copy()
    wss, distorsions = plot_wss_kmean(data, 21, f"tsne-2d_{prefixfull}")
    # print(wss, distorsions, silhouettes)

    for n in CLUSTER_RANGE:
        km = KMeans(n_clusters=n, random_state=0)
        km.fit(data)
        df_with_exposure_within[f"cluster_{n}"] = km.labels_

    df_ori_within = df_ori_within.merge(
        df_with_exposure_within[
            ["city_lower", "hex_id", "res"]
            + ["cluster_" + str(n) for n in CLUSTER_RANGE]
        ],
        on=["city_lower", "hex_id", "res"],
        how="inner",
    ).drop_duplicates()

    df_ori_within.to_csv(
        os.path.join(
            DATA_FOLDER,
            f"c_seg_cat={N_CAT}_res={res}_withincity{prefixfull}_tsne_cluster_range.csv",
        ),
        index=False,
    )
    return df_ori_within


# summarize the cluster type
def summarize_cluster(df_ori_within, n, prefix):
    """summarize the cluster type by calculating the mean of each category within each cluster"""
    variable_order = variables_sel_order[prefix]
    df_summary = (
        df_ori_within[variable_order + [f"cluster_{n}"]]
        .groupby(f"cluster_{n}")
        .mean()
        .stack()
        .reset_index()
        .rename(columns={"level_1": "category", 0: "std_value"})
    )

    df_summary_update = []
    for v in df_summary["category"].unique():
        temp = df_summary[df_summary["category"] == v].reset_index(drop=True)
        temp["norm_value"] = (temp["std_value"] - temp["std_value"].min()) / (
            temp["std_value"].max() - temp["std_value"].min()
        )
        df_summary_update.append(temp)

    df_summary_update = pd.concat(df_summary_update).reset_index()

    df_heat = df_summary_update.pivot(
        columns="category", values="norm_value", index=f"cluster_{n}"
    )[variable_order].sort_values(variable_order[:5], ascending=False)
    return df_heat


def plot_summary(df_ori_within, n, prefixfull):
    if prefixfull == "":
        figsize = (14, 4.5)
    else:
        figsize = (11, 4.5)
    fig, ax = plt.subplots(figsize=figsize)
    # use a gradient color
    df_heat = summarize_cluster(df_ori_within, n, prefixfull)
    cmap = sns.color_palette("blend:#88572C,#ddb27c,#b5f2f5,#12939a", as_cmap=True)
    sns.heatmap(
        df_heat.sort_values(["skyscraper", "building"]),
        cmap=cmap,
        annot=True,
        fmt=".2f",
        ax=ax,
    )
    # show axis annotation larger
    ax.tick_params(axis="both", which="major", labelsize=12)
    # show ticks to the left
    ax.yaxis.tick_left()
    plt.yticks(rotation=0)
    # show ticks to the bottom
    ax.xaxis.tick_top()
    # rotate the x axis
    plt.xticks(rotation=45)
    plt.tight_layout()
    # save figure to svg
    plt.savefig(
        os.path.join(GRAPHIC_PATH, f"cluster_svf_attributes_{n}{prefixfull}.svg"),
        dpi=200,
        bbox_inches="tight",
    )
    plt.close(fig)


def main(prefixfull=PREFIXFULL):
    # Generate the clusters and save the dataframe
    df_ori_within = generate_cluster(prefixfull)
    print("df_ori_within shape:", df_ori_within.shape)
    print("Done clustering process.")
    # now plot a summary
    for n in CLUSTER_RANGE:
        plot_summary(df_ori_within, n, prefixfull)
        print(f"Done plotting for cluster {n} with prefix {prefixfull}.")
    # plot the summary for all clusters
    print("Done plotting process.")


if __name__ == "__main__":
    main()
