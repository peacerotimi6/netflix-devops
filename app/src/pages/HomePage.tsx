import Stack from "@mui/material/Stack";
import { useEffect } from "react";

import { COMMON_TITLES } from "src/constant";
import HeroSection from "src/components/HeroSection";
import SliderRowForGenre from "src/components/VideoSlider";
import { useGetGenresQuery } from "src/store/slices/genre";
import { MEDIA_TYPE } from "src/types/Common";
import { Genre, CustomGenre } from "src/types/Genre";

export function Component() {
  const {
    data: genres = [],
    isLoading,
    isError,
    refetch,
  } = useGetGenresQuery(MEDIA_TYPE.Movie);

  useEffect(() => {
    // optional safety: refetch on mount
    refetch();
  }, [refetch]);

  return (
    <Stack spacing={2}>
      {/* HERO ALWAYS SHOWS */}
      <HeroSection mediaType={MEDIA_TYPE.Movie} />

      {/* LOADING STATE */}
      {isLoading && (
        <div style={{ color: "white", padding: "10px" }}>
          Loading movies...
        </div>
      )}

      {/* ERROR STATE */}
      {isError && (
        <div style={{ color: "red", padding: "10px" }}>
          Failed to load movies. Check API / Redux setup.
        </div>
      )}

      {/* MOVIES ALWAYS RENDER SAFELY */}
      {genres?.length > 0 &&
        [...COMMON_TITLES, ...genres].map((genre: Genre | CustomGenre) => (
          <SliderRowForGenre
            key={genre.id || genre.name}
            genre={genre}
            mediaType={MEDIA_TYPE.Movie}
          />
        ))}

      {/* EMPTY STATE */}
      {!isLoading && genres?.length === 0 && (
        <div style={{ color: "white", padding: "10px" }}>
          No movies found.
        </div>
      )}
    </Stack>
  );
}

Component.displayName = "HomePage";